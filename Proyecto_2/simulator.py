from typing import List, Dict, Optional

from instruction import Instruction
from assembler import Assembler, AssemblerError


class Simulator:
    """
    Simulador secuencial simple que soporta:
    add, sub, addi, and, or, lw, sw, beq, bne, jal

    Más adelante:
      - Se extenderá a pipeline de 5 etapas.
      - Se agregarán configuraciones de hazards/predicción.
    """

    def __init__(self):
        self.program_loaded = False
        self.instructions: List[Instruction] = []
        self.pc: int = 0  # en bytes
        self.registers: List[int] = [0] * 32
        self.data_memory: Dict[int, int] = {}  # dir -> valor
        self.halted: bool = False

        # Composición: el simulador usa un ensamblador
        self.assembler = Assembler()

    # --------------------------------------------------------
    # Carga de programa / reset
    # --------------------------------------------------------
    def load_program_from_source(self, source_code: str):
        if not source_code.strip():
            raise ValueError("El programa está vacío.")

        try:
            instrs = self.assembler.assemble(source_code)
        except AssemblerError as e:
            # Propagamos como ValueError para que la GUI lo muestre
            raise ValueError(str(e)) from e

        self.instructions = instrs
        self.pc = 0
        self.registers = [0] * 32
        self.data_memory = {}
        self.halted = False
        self.program_loaded = True

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
        print("[Simulator] Reset.")

    # --------------------------------------------------------
    # Ejecución
    # --------------------------------------------------------
    def step(self):
        """
        Ejecuta UNA instrucción (modelo secuencial).
        Más adelante esto será un ciclo de pipeline.
        """
        if not self.program_loaded:
            raise RuntimeError("No hay programa cargado.")
        if self.halted:
            print("[Simulator] Programa ya terminó (halted).")
            return

        idx = self.pc // 4
        if idx < 0 or idx >= len(self.instructions):
            self.halted = True
            print("[Simulator] PC fuera de rango. Programa terminado.")
            return

        instr = self.instructions[idx]
        print(f"[Simulator] PC={self.pc} | Ejecutando: {instr.text}")

        # Por defecto, siguiente instrucción = pc + 4
        next_pc = self.pc + 4

        op = instr.opcode

        # Helper para escribir registro respetando x0
        def write_reg(rd: Optional[int], value: int):
            if rd is None:
                return
            if rd == 0:
                return  # x0 siempre 0
            self.registers[rd] = value

        # ----- Ejecución según opcode -----
        if op == "add":
            write_reg(instr.rd, self.registers[instr.rs1] + self.registers[instr.rs2])

        elif op == "sub":
            write_reg(instr.rd, self.registers[instr.rs1] - self.registers[instr.rs2])

        elif op == "addi":
            write_reg(instr.rd, self.registers[instr.rs1] + instr.imm)

        elif op == "and":
            write_reg(instr.rd, self.registers[instr.rs1] & self.registers[instr.rs2])

        elif op == "or":
            write_reg(instr.rd, self.registers[instr.rs1] | self.registers[instr.rs2])

        elif op == "lw":
            addr = self.registers[instr.rs1] + instr.imm
            value = self.data_memory.get(addr, 0)
            write_reg(instr.rd, value)

        elif op == "sw":
            addr = self.registers[instr.rs1] + instr.imm
            value = self.registers[instr.rs2]
            self.data_memory[addr] = value

        elif op == "beq":
            if self.registers[instr.rs1] == self.registers[instr.rs2]:
                next_pc = instr.target_addr

        elif op == "bne":
            if self.registers[instr.rs1] != self.registers[instr.rs2]:
                next_pc = instr.target_addr

        elif op == "jal":
            # rd = dirección de retorno (pc + 4)
            write_reg(instr.rd, self.pc + 4)
            next_pc = instr.target_addr

        else:
            raise RuntimeError(f"Opcode no soportado en ejecución: {op}")

        # Forzar x0 = 0 siempre
        self.registers[0] = 0

        # Actualizar PC
        self.pc = next_pc

    def run(self, max_steps: int = 10000):
        """
        Ejecuta hasta que termine el programa o se alcance max_steps,
        para evitar loops infinitos.
        """
        if not self.program_loaded:
            raise RuntimeError("No hay programa cargado.")

        steps = 0
        while not self.halted and steps < max_steps:
            self.step()
            steps += 1

        if steps >= max_steps:
            print("[Simulator] Se alcanzó max_steps, posible loop infinito.")
        else:
            print(f"[Simulator] Ejecución completa en {steps} pasos.")

    # --------------------------------------------------------
    # Para futura integración con la GUI (panel derecho)
    # --------------------------------------------------------
    def get_state(self):
        """
        Devuelve un snapshot sencillo del estado actual.
        La GUI podrá usar esto para mostrar registros/memoria.
        """
        return {
            "pc": self.pc,
            "registers": list(self.registers),
            "data_memory": dict(self.data_memory),
            "halted": self.halted,
        }
