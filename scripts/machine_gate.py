"""Defer a build only when macOS reports memory pressure that is not normal."""

import os
import subprocess


def check(kind="build"):
    assert kind in ("build", "emulator")
    try:
        pressure = subprocess.check_output(
            ["sysctl", "-n", "kern.memorystatus_vm_pressure_level"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return  # not macOS: no memory-pressure reading
    print(subprocess.check_output(["uptime"], text=True).strip(), flush=True)
    if pressure != "1":
        raise RuntimeError(
            f"Launch deferred: memory pressure={pressure}, one-minute load={os.getloadavg()[0]:.2f}"
        )
