from dataclasses import dataclass
from typing import Optional, List, Dict

from instruction import Instruction
from assembler import assemble, AssemblerError


# ------------------------------------------------------------
# Registros de pipeline
# ------------------------------------------------------------
@dataclass
class IF_ID_Reg:
    instr: Optional[Instruction] = None
    pc: int = 0


@dataclass
class ID_EX_Reg:
    instr: Optional[Instruction] = None
    pc: int = 0
    rs1_val: int = 0
    rs2_val: int = 0
    imm: int = 0


@dataclass
class EX_MEM_Reg:
    instr: Optional[Instruction] = None
    pc: int = 0
    alu_result: int = 0
    rs2_val: int = 0      # para sw
    branch_taken: bool = False


@dataclass
class MEM_WB_Reg:
    instr: Optional[Instruction] = None
    pc: int = 0
    write_value: int = 0  # valor que eventualmente irá a rd


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
def instr_writes_rd(instr: Instruction) -> bool:
    """Indica si la instrucción escribe un registro destino."""
    if instr.rd is None or instr.rd == 0:
        return False
    return instr.opcode in ("add", "sub", "addi", "and", "or", "lw", "jal")


def is_nop_stage(stage) -> bool:
    return stage.instr is None


# ------------------------------------------------------------
# Simulador con pipeline de 5 etapas
# ------------------------------------------------------------
class Simulator:
    """
    Simulador con pipeline de 5 etapas:

      IF -> ID -> EX -> MEM -> WB

    Soporta:
      add, sub, addi, and, or, lw, sw, beq, bne, jal

    Cada llamada a step() = 1 ciclo de reloj del pipeline.
    """

    def __init__(self):
        self.program_loaded = False
        self.instructions: List[Instruction] = []
        self.pc: int = 0            # PC para el FETCH (en bytes)
        self.registers: List[int] = [0] * 32
        self.data_memory: Dict[int, int] = {}
        self.halted: bool = False

        # Registros de pipeline
        self.IF_ID = IF_ID_Reg()
        self.ID_EX = ID_EX_Reg()
        self.EX_MEM = EX_MEM_Reg()
        self.MEM_WB = MEM_WB_Reg()

        self.cycle = 0

    # --------------------------------------------------------
    # Carga de programa / reset
    # --------------------------------------------------------
    def _reset_pipeline_regs(self):
        self.IF_ID = IF_ID_Reg()
        self.ID_EX = ID_EX_Reg()
        self.EX_MEM = EX_MEM_Reg()
        self.MEM_WB = MEM_WB_Reg()

    def load_program_from_source(self, source_code: str):
        if not source_code.strip():
            raise ValueError("El programa está vacío.")

        try:
            instrs = assemble(source_code)
        except AssemblerError as e:
            # Reempaquetamos en ValueError para que la GUI lo muestre
            raise ValueError(str(e)) from e

        self.instructions = instrs
        self.pc = 0
        self.registers = [0] * 32
        self.data_memory = {}
        self.halted = False
        self.program_loaded = True
        self.cycle = 0
        self._reset_pipeline_regs()

        print(f"[Simulator] Programa cargado: {len(instrs)} instrucciones.")

    def reset(self):
        """
        Resetear estado del simulador (perdemos registros y memoria,
        mantenemos el programa cargado si lo había).
        """
        self.pc = 0
        self.registers = [0] * 32
        self.data_memory = {}
        self.halted = False
        self.cycle = 0
        self._reset_pipeline_regs()
        print("[Simulator] Reset.")

    # --------------------------------------------------------
    # Ejecución (pipeline)
    # --------------------------------------------------------
    def step(self):
        """
        Ejecuta UN ciclo de reloj del pipeline.
        """
        if not self.program_loaded:
            raise RuntimeError("No hay programa cargado.")
        if self.halted:
            print("[Simulator] Programa ya terminó (halted).")
            return

        self.cycle += 1
        print(f"[Simulator] Ciclo {self.cycle}, PC(fetch)={self.pc}")

        # Copias "viejas" de los registros de pipeline
        old_IF_ID = self.IF_ID
        old_ID_EX = self.ID_EX
        old_EX_MEM = self.EX_MEM
        old_MEM_WB = self.MEM_WB
        old_pc = self.pc

        # ----------------------------------------------------
        # 1) WB
        # ----------------------------------------------------
        if old_MEM_WB.instr is not None:
            instr = old_MEM_WB.instr
            if instr_writes_rd(instr):
                rd = instr.rd
                if rd is not None and rd != 0:
                    self.registers[rd] = old_MEM_WB.write_value
                    print(f"  [WB] x{rd} <- {old_MEM_WB.write_value}")

        # Forzar x0 = 0
        self.registers[0] = 0

        # ----------------------------------------------------
        # 2) MEM
        # ----------------------------------------------------
        new_MEM_WB = MEM_WB_Reg()
        if old_EX_MEM.instr is not None:
            instr = old_EX_MEM.instr
            op = instr.opcode
            new_MEM_WB.instr = instr
            new_MEM_WB.pc = old_EX_MEM.pc

            if op == "lw":
                addr = old_EX_MEM.alu_result
                value = self.data_memory.get(addr, 0)
                new_MEM_WB.write_value = value
                print(f"  [MEM] lw desde [{addr}] = {value}")
            elif op == "sw":
                addr = old_EX_MEM.alu_result
                value = old_EX_MEM.rs2_val
                self.data_memory[addr] = value
                new_MEM_WB.write_value = 0  # no hay writeback
                print(f"  [MEM] sw {value} -> [{addr}]")
            elif op in ("add", "sub", "addi", "and", "or", "jal"):
                new_MEM_WB.write_value = old_EX_MEM.alu_result
            else:
                # beq, bne u otros sin writeback
                new_MEM_WB.write_value = old_EX_MEM.alu_result

        # ----------------------------------------------------
        # 3) EX
        # ----------------------------------------------------
        new_EX_MEM = EX_MEM_Reg()
        branch_taken = False
        branch_target = None

        if old_ID_EX.instr is not None:
            instr = old_ID_EX.instr
            op = instr.opcode

            new_EX_MEM.instr = instr
            new_EX_MEM.pc = old_ID_EX.pc

            rs1 = instr.rs1 if instr.rs1 is not None else 0
            rs2 = instr.rs2 if instr.rs2 is not None else 0
            rs1_val = old_ID_EX.rs1_val
            rs2_val = old_ID_EX.rs2_val

            # ---- Forwarding (EX/MEM, MEM/WB) ----
            def forward(val: int, regnum: int) -> int:
                if regnum == 0:
                    return val

                # Desde EX/MEM (solo si no es lw, porque ahí alu_result es dirección)
                if old_EX_MEM.instr is not None:
                    i_em = old_EX_MEM.instr
                    if instr_writes_rd(i_em) and i_em.opcode != "lw":
                        rd_em = i_em.rd
                        if rd_em is not None and rd_em != 0 and rd_em == regnum:
                            return old_EX_MEM.alu_result

                # Desde MEM/WB (incluye lw)
                if old_MEM_WB.instr is not None:
                    i_mw = old_MEM_WB.instr
                    if instr_writes_rd(i_mw):
                        rd_mw = i_mw.rd
                        if rd_mw is not None and rd_mw != 0 and rd_mw == regnum:
                            return old_MEM_WB.write_value

                return val

            op1 = forward(rs1_val, rs1)
            op2_reg = forward(rs2_val, rs2)
            imm = old_ID_EX.imm

            alu_result = 0
            branch_taken_local = False

            if op == "add":
                alu_result = op1 + op2_reg
            elif op == "sub":
                alu_result = op1 - op2_reg
            elif op == "addi":
                alu_result = op1 + imm
            elif op == "and":
                alu_result = op1 & op2_reg
            elif op == "or":
                alu_result = op1 | op2_reg
            elif op in ("lw", "sw"):
                alu_result = op1 + imm  # dirección efectiva
            elif op == "beq":
                branch_taken_local = (op1 == op2_reg)
            elif op == "bne":
                branch_taken_local = (op1 != op2_reg)
            elif op == "jal":
                # alu_result = dirección de retorno
                alu_result = old_ID_EX.pc + 4
                branch_taken_local = True

            if op in ("beq", "bne"):
                if branch_taken_local:
                    branch_taken = True
                    branch_target = instr.target_addr
            elif op == "jal":
                branch_taken = True
                branch_target = instr.target_addr

            new_EX_MEM.alu_result = alu_result
            new_EX_MEM.rs2_val = op2_reg
            new_EX_MEM.branch_taken = branch_taken_local

        # ----------------------------------------------------
        # 4) ID (con detección de hazard lw-uso)
        # ----------------------------------------------------
        new_ID_EX = ID_EX_Reg()
        stall_IF = False

        if old_IF_ID.instr is not None:
            instr = old_IF_ID.instr

            # Hazard de carga-uso: si hay lw en EX (old_ID_EX) y esta instr usa rd
            load_use_stall = False
            if old_ID_EX.instr is not None and old_ID_EX.instr.opcode == "lw":
                lw_instr = old_ID_EX.instr
                lw_rd = lw_instr.rd
                if lw_rd is not None and lw_rd != 0:
                    uses_rs1 = (instr.rs1 == lw_rd)
                    uses_rs2 = (instr.rs2 == lw_rd)
                    if uses_rs1 or uses_rs2:
                        load_use_stall = True

            if branch_taken:
                # Se tomó un branch en EX: vaciamos esta etapa (flush)
                pass  # new_ID_EX sigue siendo NOP
            elif load_use_stall:
                # Insertar burbuja en EX, congelar IF/ID y PC
                stall_IF = True
            else:
                # Decodificación normal
                new_ID_EX.instr = instr
                new_ID_EX.pc = old_IF_ID.pc
                rs1 = instr.rs1 if instr.rs1 is not None else 0
                rs2 = instr.rs2 if instr.rs2 is not None else 0
                new_ID_EX.rs1_val = self.registers[rs1]
                new_ID_EX.rs2_val = self.registers[rs2]
                new_ID_EX.imm = instr.imm or 0

        # ----------------------------------------------------
        # 5) IF
        # ----------------------------------------------------
        # Cálculo de PC siguiente
        if branch_taken and branch_target is not None:
            pc_next = branch_target
        else:
            pc_next = old_pc + 4

        new_IF_ID = IF_ID_Reg()

        if branch_taken:
            # No hacemos fetch en este ciclo; la próxima instrucción se busca desde branch_target
            new_IF_ID.instr = None
            new_IF_ID.pc = pc_next
        elif stall_IF:
            # Congelamos IF/ID y PC (para hazard lw-uso)
            new_IF_ID = old_IF_ID
            pc_next = old_pc
        else:
            # Fetch normal
            idx = old_pc // 4
            if 0 <= idx < len(self.instructions):
                instr = self.instructions[idx]
                new_IF_ID.instr = instr
                new_IF_ID.pc = old_pc
            else:
                new_IF_ID.instr = None
                new_IF_ID.pc = old_pc  # fuera de rango => NOP

        # ----------------------------------------------------
        # Actualizar estado global
        # ----------------------------------------------------
        self.IF_ID = new_IF_ID
        self.ID_EX = new_ID_EX
        self.EX_MEM = new_EX_MEM
        self.MEM_WB = new_MEM_WB
        self.pc = pc_next

        # Mantener x0 en 0
        self.registers[0] = 0

        # ¿Terminó el programa?
        idx_fetch = self.pc // 4
        no_more_fetch = not (0 <= idx_fetch < len(self.instructions))
        pipeline_empty = (
            is_nop_stage(self.IF_ID)
            and is_nop_stage(self.ID_EX)
            and is_nop_stage(self.EX_MEM)
            and is_nop_stage(self.MEM_WB)
        )
        if no_more_fetch and pipeline_empty:
            self.halted = True
            print("[Simulator] Pipeline vacío, programa terminado.")

    def run(self, max_cycles: int = 10000):
        """
        Ejecuta hasta que termine el programa o se alcance max_cycles
        (para evitar loops infinitos).
        """
        if not self.program_loaded:
            raise RuntimeError("No hay programa cargado.")

        cycles = 0
        while not self.halted and cycles < max_cycles:
            self.step()
            cycles += 1

        if cycles >= max_cycles:
            print("[Simulator] Se alcanzó max_cycles, posible loop infinito.")
        else:
            print(f"[Simulator] Ejecución completa en {cycles} ciclos.")

    # --------------------------------------------------------
    # Estado para la GUI
    # --------------------------------------------------------
    def _stage_info(self, stage) -> Dict:
        instr = stage.instr
        if instr is None:
            return {"pc": None, "opcode": None, "text": None}
        return {"pc": stage.pc, "opcode": instr.opcode, "text": instr.text}

    def get_state(self):
        """
        Devuelve un snapshot del estado actual, incluyendo pipeline.
        """
        return {
            "pc": self.pc,
            "registers": list(self.registers),
            "data_memory": dict(self.data_memory),
            "halted": self.halted,
            "cycle": self.cycle,
            "pipeline": {
                "IF": self._stage_info(self.IF_ID),
                "ID": self._stage_info(self.ID_EX),
                "EX": self._stage_info(self.EX_MEM),
                "MEM": self._stage_info(self.EX_MEM),   # salida de EX / entrada de MEM
                "WB": self._stage_info(self.MEM_WB),
            },
        }
