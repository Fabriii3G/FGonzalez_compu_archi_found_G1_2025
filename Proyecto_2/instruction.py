from dataclasses import dataclass
from typing import Optional


# ------------------------------------------------------------
# Representación interna de una instrucción RISC-V (subset)
# ------------------------------------------------------------
@dataclass
class Instruction:
    opcode: str
    rd: Optional[int] = None
    rs1: Optional[int] = None
    rs2: Optional[int] = None
    imm: Optional[int] = None
    target_addr: Optional[int] = None  # para beq/bne/jal
    address: int = 0                   # PC (en bytes) donde vive la instrucción
    line: int = 0                      # línea original del código (para errores/debug)
    text: str = ""                     # texto original de la instrucción


