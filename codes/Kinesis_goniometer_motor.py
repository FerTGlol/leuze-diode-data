# =============================================================================
# goniometer_scan.py
# KPRM1E (KCube Brushless Motor) + PM100A via TLPM DLL
# =============================================================================

import time
import csv
import ctypes
import os

# =============================================================================
# ── LEUZE COMPUTER-DEPENDENT CONFIGURATION (FILL IN BEFORE RUNNING) ──────────
# =============================================================================

# Enter the unique 8-digit serial number found on your specific physical Thorlabs KCube box.
# Example: "27501531"
ROTATION_SERIAL   = "" 

# Enter the absolute path to your Thorlabs Kinesis installation directory.
# Example: r"C:\Program Files\Thorlabs\Kinesis"
KINESIS_PATH      = r""

# Enter the absolute path to your Thorlabs Power Meter (TLPM) 64-bit DLL file.
# Example: r"C:\Program Files\IVI Foundation\VISA\Win64\Bin\TLPM_64.dll"
TLPM_DLL_PATH     = r""

# =============================================================================
# ── PARAMETRIC EXPERIMENT PARAMETERS ─────────────────────────────────────────
# =============================================================================

ANGLE_START       = 0
ANGLE_END         = 360
ANGLE_STEP        = 1
SAMPLES_PER_ANGLE = 50
SAMPLE_DELAY_S    = 0.005
SETTLE_TIME_S     = 0.5

# Metadata variables for file designation
DIODE             = "204"
OPOWER            = "8_67uW"
CURRENT_MA        = "27_7_mA"

OUTPUT_CSV = f"Diode_{DIODE}_P{OPOWER}_I{CURRENT_MA}.csv"

# =============================================================================
# ── PM100A via TLPM DLL ───────────────────────────────────────────────────────
# =============================================================================

class PM100A_TLPM:
    def __init__(self, dll_path: str = TLPM_DLL_PATH):
        if not dll_path or not os.path.exists(dll_path):
            raise FileNotFoundError(
                f"TLPM DLL path is empty or invalid. Please check 'TLPM_DLL_PATH' configuration.\n"
                f"Path attempted: {dll_path}"
            )

        self.lib = ctypes.cdll.LoadLibrary(dll_path)
        print(f"[TLPM] DLL loaded successfully: {dll_path}")

        # Count available instruments
        count = ctypes.c_uint32(0)
        ret = self.lib.TLPM_findRsrc(None, ctypes.byref(count))
        if ret != 0 or count.value == 0:
            raise RuntimeError(
                f"TLPM_findRsrc: No PM100A instruments found (ret={ret}, count={count.value}).\n"
                "Verify that the PM100A power meter console is securely connected via USB."
            )
        print(f"[TLPM] Instruments found on hub: {count.value}")

        # Get name of the first resource
        resource = ctypes.create_string_buffer(256)
        ret = self.lib.TLPM_getRsrcName(None, 0, resource)
        if ret != 0:
            raise RuntimeError(f"TLPM_getRsrcName failed (ret={ret})")

        rsrc_name = resource.value
        print(f"[TLPM] Target Resource: {rsrc_name.decode(errors='replace')}")

        # Open handle
        self.handle = ctypes.c_ulong(0)
        ret = self.lib.TLPM_init(
            rsrc_name,
            ctypes.c_bool(True),   # id_query
            ctypes.c_bool(False),  # reset_device
            ctypes.byref(self.handle)
        )
        if ret != 0:
            raise RuntimeError(f"TLPM_init failed (ret={ret:#010x})")

        print("[PM100A] Connected successfully.")

        # Enable Auto-Range
        self.lib.TLPM_setPowerAutoRange(self.handle, ctypes.c_int16(1))

    def read_power(self) -> float:
        power = ctypes.c_double(0.0)
        ret = self.lib.TLPM_measPower(self.handle, ctypes.byref(power))
        if ret != 0:
            return float("nan")
        return power.value

    def close(self):
        self.lib.TLPM_close(self.handle)
        print("[TLPM] PM100A disconnected.")

# =============================================================================
# ── KPRM1E: KCube Brushless Motor ────────────────────────────────────────────
# =============================================================================

class KinesisRotationMount:

    _DEV_UNITS_PER_DEG = 1919.64

    def __init__(self, serial: str, kinesis_path: str):
        if not serial:
            raise ValueError("ROTATION_SERIAL is blank. Please specify your device serial number.")
        if not kinesis_path or not os.path.exists(kinesis_path):
            raise FileNotFoundError(f"Kinesis software path is invalid. Check 'KINESIS_PATH'.")

        self.serial = serial.encode()

        dll_path = os.path.join(kinesis_path, "Thorlabs.MotionControl.KCube.BrushlessMotor.dll")
        if not os.path.exists(dll_path):
            raise FileNotFoundError(f"KCube Brushless Motor DLL not found at:\n{dll_path}")

        os.add_dll_directory(kinesis_path)
        self.lib = ctypes.cdll.LoadLibrary(dll_path)

        self.lib.TLI_BuildDeviceList()
        time.sleep(0.5)

        ret = self.lib.BMC_Open(self.serial)
        if ret != 0:
            raise RuntimeError(
                f"BMC_Open failed (error={ret}). "
                "Is the Thorlabs Kinesis GUI application currently open? Close it and try again."
            )

        self.lib.BMC_LoadSettings(self.serial)
        self.lib.BMC_StartPolling(self.serial, ctypes.c_int(200))
        time.sleep(1)

        print("[KPRM1E] Connected. Initializing homing routine...")
        self.lib.BMC_Home(self.serial)
        self._wait_for_stop(timeout=60)
        print("[KPRM1E] Homing sequence completed.")

    def _deg_to_units(self, deg: float) -> int:
        return int(deg * self._DEV_UNITS_PER_DEG)

    def _wait_for_stop(self, timeout=20):
        t0 = time.time()
        time.sleep(0.5)
        while time.time() - t0 < timeout:
            status = self.lib.BMC_GetStatusBits(self.serial)
            if not (status & 0x30):
                return
            time.sleep(0.05)
        print("[KPRM1E] Warning: Timeout reached while waiting for movement execution to complete.")

    def move_to(self, angle_deg: float):
        units = ctypes.c_int(self._deg_to_units(angle_deg))
        self.lib.BMC_MoveToPosition(self.serial, units)
        self._wait_for_stop()

    def get_position(self) -> float:
        units = self.lib.BMC_GetPosition(self.serial)
        return units / self._DEV_UNITS_PER_DEG

    def close(self):
        self.lib.BMC_StopPolling(self.serial)
        self.lib.BMC_Close(self.serial)
        print("[KPRM1E] Disconnected.")

# =============================================================================
# ── MAIN PARAMETRIC SCAN ─────────────────────────────────────────────────────
# =============================================================================

def run_scan():
    print("=" * 60)
    print("  GONIOMETER PARAMETRIC SCAN  |  KPRM1E + PM100A")
    print("=" * 60)

    stage = KinesisRotationMount(ROTATION_SERIAL, KINESIS_PATH)
    pm    = PM100A_TLPM()

    angles = []
    a = ANGLE_START
    while a <= ANGLE_END + 1e-9:
        angles.append(round(a, 4))
        a += ANGLE_STEP

    total = len(angles)
    print(f"\nScan Configuration: {total} positions × {SAMPLES_PER_ANGLE} samples")
    print(f"Output Target File: {OUTPUT_CSV}\n")

    start_time = time.time()

    with open(OUTPUT_CSV, "w", newline="") as f:
        writer = csv.writer(f)
        header = (["angle_deg"]
                  + [f"sample_{i+1}" for i in range(SAMPLES_PER_ANGLE)]
                  + ["mean_W", "std_W", "mean_uW"])
        writer.writerow(header)

        for i, angle in enumerate(angles):
            print(f"[{i+1:3d}/{total}] {angle:6.1f}°  →  moving...", end=" ", flush=True)
            stage.move_to(angle)
            time.sleep(SETTLE_TIME_S)

            samples = []
            for _ in range(SAMPLES_PER_ANGLE):
                samples.append(pm.read_power())
                time.sleep(SAMPLE_DELAY_S)

            # Drop math NaN references cleanly for calculation execution
            valid   = [s for s in samples if s == s]
            mean_W  = sum(valid) / len(valid) if valid else float("nan")
            var     = sum((s - mean_W)**2 for s in valid) / len(valid) if valid else 0
            std_W   = var ** 0.5
            mean_uW = mean_W * 1e6

            elapsed   = time.time() - start_time
            remaining = (elapsed / (i + 1)) * (total - i - 1)
            print(f"{mean_uW:10.4f} µW  ±{std_W*1e9:.2f} nW  [Estimated remaining: {remaining:.0f}s]")

            writer.writerow([angle] + samples + [mean_W, std_W, mean_uW])
            f.flush()

    print("\nScan execution complete. Homeward bound to 0°...")
    stage.move_to(0.0)
    stage.close()
    pm.close()

    total_time = time.time() - start_time
    print(f"\n✓ Telemetry data saved successfully to: {OUTPUT_CSV}")
    print(f"✓ Total runtime: {total_time/60:.1f} minutes")

# =============================================================================

if __name__ == "__main__":
    run_scan()