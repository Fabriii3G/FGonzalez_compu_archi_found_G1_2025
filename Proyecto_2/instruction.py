from dataclasses import dataclass
from typing import Optional


@dataclass
class Instruction:
    """
    Representa una instrucción RISC-V ya ensamblada en forma simbólica.
    address: PC (en bytes) donde vive esta instrucción.
    line   : número de línea original en el código fuente (para errores/debug).
    text   : texto original de la instrucción.
    """
    opcode: str
    rd: Optional[int] = None
    rs1: Optional[int] = None
    rs2: Optional[int] = None
    imm: Optional[int] = None
    target_addr: Optional[int] = None
    address: int = 0
    line: int = 0
    text: str = ""


