"""Install only the v2 launcher and its isolated existing Tk dependencies."""
from pathlib import Path
import shutil


def main():
    destination = Path("/home/wenhan/SOFTWARE/RIS-GUI-V2")
    original = Path("/home/wenhan/SOFTWARE/RIS-GUI")
    templates = Path(__file__).resolve().parent
    if destination.exists():
        raise SystemExit(f"目标目录已存在，未覆盖：{destination}")
    for name in ("runtime", "packages"):
        if not (original / name).is_dir():
            raise SystemExit(f"缺少已有依赖：{original / name}")
    destination.mkdir()
    for name in ("runtime", "packages"):
        shutil.copytree(original / name, destination / name, symlinks=True)
    (destination / "logs").mkdir()
    for name in ("start-ris-gui.sh", "ris-gui-v2.desktop", "README.txt"):
        shutil.copy2(templates / name, destination / name)
    for name in ("start-ris-gui.sh", "ris-gui-v2.desktop"):
        (destination / name).chmod(0o755)
    print(f"新版独立启动入口：{destination / 'start-ris-gui.sh'}")
    print(f"图形入口：{destination / 'ris-gui-v2.desktop'}")
    print("旧版入口及运行库保持不变。")


if __name__ == "__main__":
    main()
