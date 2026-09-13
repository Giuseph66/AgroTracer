#!/usr/bin/env python3
"""
Leitor de brincos UHF — FONKAN FI-504 (ISO18000-6C / EPC Gen2) via USB-TTL.

Protocolo (verificado em bancada, 2026-09-12):
  - Serial 38400 8N1
  - Comando:  <LF> cmd <CR>          ex: b"\\nU\\r"
  - Resposta: <LF> dados <CR><LF>    ex: b"\\nU3000E280...2A5C\\r\\n"
  - Q  leitura única      -> "Q<PC 4hex><EPC 24hex><CRC 4hex>" ou "Q" (sem tag)
  - U  leitura multi-tag  -> uma linha "U<PC><EPC><CRC>" por tag, termina com "U" vazio
  - V  versão firmware    -> "VC3CB,00016A95,B1,1"
  - S  número de série    -> "S00016A95"   (NUNCA enviar S com argumento: grava serial)
  - X  = comando inválido

Uso:
  ./fonkan_reader.py                 # leitura contínua, mostra cada tag nova
  ./fonkan_reader.py --once          # espera a primeira tag, imprime EPC e sai
  ./fonkan_reader.py --csv leituras.csv
  ./fonkan_reader.py --all           # imprime toda leitura, sem dedup
  ./fonkan_reader.py --info          # só versão/serial
  ./fonkan_reader.py --port /dev/ttyACM0

Dependência: pyserial  (pip install pyserial  |  apt install python3-serial)
"""
import argparse
import csv
import glob
import sys
import time
from dataclasses import dataclass

try:
    import serial
except ImportError:
    sys.exit("pyserial ausente: pip install pyserial  (ou: sudo apt install python3-serial)")

BAUD = 38400
PORT_GLOBS = ["/dev/ttyCH343USB*", "/dev/ttyACM*", "/dev/ttyUSB*"]


@dataclass
class Tag:
    pc: str
    epc: str
    crc: str


def find_port() -> str:
    for pattern in PORT_GLOBS:
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[0]
    sys.exit("Nenhuma porta serial encontrada. Leitor plugado? Use --port.")


class Fonkan:
    def __init__(self, port: str):
        self.ser = serial.Serial(port, BAUD, bytesize=8, parity="N", stopbits=1,
                                 timeout=0.02, xonxoff=False, rtscts=False, dsrdtr=False)
        time.sleep(0.3)
        self.ser.reset_input_buffer()

    def close(self):
        self.ser.close()

    def cmd(self, c: str, quiet_ms: int = 150) -> list[str]:
        """Envia comando e devolve linhas de resposta (sem CR/LF).
        Considera resposta completa após `quiet_ms` sem dados novos."""
        self.ser.reset_input_buffer()
        self.ser.write(b"\n" + c.encode("ascii") + b"\r")
        self.ser.flush()
        buf = bytearray()
        last = time.time()
        while time.time() - last < quiet_ms / 1000:
            chunk = self.ser.read(1024)
            if chunk:
                buf.extend(chunk)
                last = time.time()
        text = buf.decode("ascii", "replace").replace("\r", "")
        return [ln for ln in text.split("\n") if ln]

    def version(self) -> str:
        return ",".join(l[1:] for l in self.cmd("V") if l.startswith("V")) or "?"

    def serial_number(self) -> str:
        return "".join(l[1:] for l in self.cmd("S") if l.startswith("S")) or "?"

    def inventory(self) -> list[Tag]:
        """Multi-tag ('U'). Lista vazia = nenhuma tag no campo."""
        tags = []
        for ln in self.cmd("U"):
            if ln.startswith("U") and len(ln) >= 1 + 4 + 4 + 4:
                body = ln[1:]
                tags.append(Tag(pc=body[:4], epc=body[4:-4], crc=body[-4:]))
        return tags


def main() -> int:
    ap = argparse.ArgumentParser(description="Leitor UHF FONKAN FI-504")
    ap.add_argument("--port", help="porta serial (auto-detecta se omitido)")
    ap.add_argument("--once", action="store_true", help="lê a primeira tag e sai")
    ap.add_argument("--all", action="store_true", help="imprime toda leitura (sem dedup)")
    ap.add_argument("--csv", metavar="ARQ", help="grava leituras em CSV (append)")
    ap.add_argument("--info", action="store_true", help="mostra versão/serial e sai")
    ap.add_argument("--cooldown", type=float, default=2.0,
                    help="segundos até reimprimir a mesma tag no modo contínuo (padrão 2)")
    ap.add_argument("--interval", type=float, default=0.1, help="intervalo entre polls (s)")
    args = ap.parse_args()

    port = args.port or find_port()
    rd = Fonkan(port)
    print(f"porta   : {port} @ {BAUD}")
    print(f"firmware: {rd.version()}")
    print(f"serial  : {rd.serial_number()}")
    if args.info:
        rd.close()
        return 0

    writer = None
    if args.csv:
        fh = open(args.csv, "a", newline="")
        writer = csv.writer(fh)
        if fh.tell() == 0:
            writer.writerow(["timestamp", "epc", "pc", "crc"])

    last_seen: dict[str, float] = {}
    counts: dict[str, int] = {}
    print("lendo... (Ctrl+C para sair)" if not args.once else "aproxime a tag...")
    try:
        while True:
            now = time.time()
            for t in rd.inventory():
                counts[t.epc] = counts.get(t.epc, 0) + 1
                fresh = args.all or (now - last_seen.get(t.epc, 0) >= args.cooldown)
                last_seen[t.epc] = now
                if fresh:
                    ts = time.strftime("%Y-%m-%d %H:%M:%S")
                    print(f"{ts}  EPC {t.epc}  pc={t.pc} crc={t.crc}  (#{counts[t.epc]})", flush=True)
                    if writer:
                        writer.writerow([ts, t.epc, t.pc, t.crc])
                if args.once:
                    print(t.epc)
                    return 0
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print(f"\n{len(counts)} tag(s) distinta(s):")
        for epc, n in sorted(counts.items(), key=lambda kv: -kv[1]):
            print(f"  {epc}  x{n}")
    finally:
        rd.close()
        if writer:
            fh.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
