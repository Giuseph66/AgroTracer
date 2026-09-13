# Leitor UHF FONKAN FI-504

Leitor de brincos EPC Gen2 (902–928 MHz) usado nos testes de campo do TraceAgro.

- Módulo: FONKAN FI-504 (AliExpress, FONKAN Store) + USB-TTL CH9101 (`1a86:55d8`)
- Porta Linux: `/dev/ttyCH343USB0` (driver WCH `ch343`) ou `/dev/ttyACM0` (`cdc_acm`)
- **38400 8N1, protocolo ASCII** `<LF>cmd<CR>` → `<LF>resp<CR><LF>`
- O "YRM100 SDK" enviado pelo vendedor **não** corresponde a este firmware. Ignorar.

```bash
pip install pyserial
./fonkan_reader.py            # contínuo
./fonkan_reader.py --once     # primeira tag e sai (útil em pipeline)
./fonkan_reader.py --csv leituras.csv
```

Sem permissão na porta: `sudo usermod -aG dialout $USER` e relogar.

Comandos conhecidos: `Q` leitura única, `U` multi-tag, `V` versão, `S` serial.
Não enviar `S<arg>` (regrava serial) nem `U<arg>`/`G<n>` sem documentação.
