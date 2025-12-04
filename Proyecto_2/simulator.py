from dataclasses import dataclass
from typing import Optional, List, Dict
from enum import Enum

from instruction import Instruction
from assembler import assemble, AssemblerError


# ------------------------------------------------------------
# Políticas de riesgos
# ------------------------------------------------------------
class HazardPolicy(Enum):
    """
    Políticas de resolución de riesgos en el pipeline:
    
    a) NO_HAZARD_UNIT: Sin unidad de riesgos        Latencia: 20ns
       - NO forwarding
       - Stalls para TODAS las dependencias RAW
       - NO predicción de saltos
       - Mayor cantidad de ciclos
    
    b) WITH_HAZARD_UNIT: Con unidad de riesgos      Latencia: 25ns
       - SÍ forwarding (desde EX/MEM y MEM/WB)
       - Solo stalls en load-use hazard
       - NO predicción de saltos
       - Menor cantidad de ciclos que (a)
    
    c) WITH_BRANCH_PRED: Con predicción de saltos       Latencia: 30ns
       - NO forwarding
       - Stalls para dependencias RAW
       - SÍ predicción de saltos
       - Reduce stalls por control hazards
    
    d) FULL_HAZARD: Con unidad de riesgos Y predicción      Latencia: 30ns
       - SÍ forwarding
       - Solo stalls en load-use hazard
       - SÍ predicción de saltos
       - Menor cantidad de ciclos (óptimo)
    """
    NO_HAZARD_UNIT = 1
    WITH_HAZARD_UNIT = 2
    WITH_BRANCH_PRED = 3
    FULL_HAZARD = 4


# ------------------------------------------------------------
# Métricas de ejecución
# ------------------------------------------------------------
@dataclass
class ExecutionMetrics:
    cycles: int = 0
    instructions_executed: int = 0
    stalls: int = 0
    branch_mispredictions: int = 0
    correct_predictions: int = 0
    data_hazards: int = 0
    control_hazards: int = 0
    
    @property
    def cpi(self) -> float:
        """Cycles per instruction"""
        if self.instructions_executed == 0:
            return 0.0
        return self.cycles / self.instructions_executed
    
    @property
    def branch_accuracy(self) -> float:
        """Porcentaje de predicciones correctas"""
        total = self.branch_mispredictions + self.correct_predictions
        if total == 0:
            return 0.0
        return (self.correct_predictions / total) * 100


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

    def __init__(self, hazard_policy: HazardPolicy = HazardPolicy.FULL_HAZARD, name: str = "Simulator"):
        self.hazard_policy = hazard_policy
        self.name = name
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
        
        # Métricas
        self.metrics = ExecutionMetrics()
        
        # Predicción de saltos (simple: siempre tomado o no tomado)
        self.branch_prediction = True  # True = siempre predicho como tomado

        self.latency = 20
        if self.hazard_policy == HazardPolicy.WITH_HAZARD_UNIT:
            self.latency = 25
        if self.hazard_policy == HazardPolicy.WITH_BRANCH_PRED:
            self.latency = 30
        if self.hazard_policy == HazardPolicy.FULL_HAZARD:
            self.latency = 30

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
        self.metrics = ExecutionMetrics()
        print(f"[{self.name}] Reset.")

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
        self.metrics.cycles += 1
        print(f"[{self.name}] Ciclo {self.cycle}, PC(fetch)={self.pc}")

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
            self.metrics.instructions_executed += 1
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
            # Solo activo si tiene unidad de riesgos
            def forward(val: int, regnum: int) -> int:
                if regnum == 0:
                    return val
                
                # Forwarding solo con unidad de riesgos
                if self.hazard_policy not in (HazardPolicy.WITH_HAZARD_UNIT, HazardPolicy.FULL_HAZARD):
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

            # Manejo de saltos
            if op in ("beq", "bne"):
                # CON PREDICCIÓN: Se asume el salto y solo se corrige si falla
                if self.hazard_policy in (HazardPolicy.WITH_BRANCH_PRED, HazardPolicy.FULL_HAZARD):
                    # Predicción: siempre asumimos que el branch se toma
                    predicted_taken = self.branch_prediction
                    
                    if branch_taken_local == predicted_taken:
                        # Predicción correcta
                        self.metrics.correct_predictions += 1
                        if branch_taken_local:
                            branch_taken = True
                            branch_target = instr.target_addr
                    else:
                        # Predicción incorrecta: flush del pipeline
                        self.metrics.branch_mispredictions += 1
                        if branch_taken_local:
                            branch_taken = True
                            branch_target = instr.target_addr
                        # Si no se toma pero predijimos que sí, también hay flush (branch_taken queda False)
                else:
                    # SIN PREDICCIÓN: Siempre esperamos a resolver el branch (flush siempre)
                    if branch_taken_local:
                        branch_taken = True
                        branch_target = instr.target_addr
                        
            elif op == "jal":
                # JAL siempre se toma
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

            # Detección de hazards de datos
            load_use_stall = False
            data_hazard_stall = False
            
            # SIN UNIDAD DE RIESGOS: necesita stalls para TODAS las dependencias RAW
            if self.hazard_policy in (HazardPolicy.NO_HAZARD_UNIT, HazardPolicy.WITH_BRANCH_PRED):
                # Stall si la instrucción en EX escribe a un registro que esta usa
                if old_ID_EX.instr is not None and instr_writes_rd(old_ID_EX.instr):
                    ex_rd = old_ID_EX.instr.rd
                    if ex_rd is not None and ex_rd != 0:
                        if instr.rs1 == ex_rd or instr.rs2 == ex_rd:
                            data_hazard_stall = True
                            self.metrics.data_hazards += 1
                            self.metrics.stalls += 1
                
                # Stall si la instrucción en MEM escribe a un registro que esta usa
                if not data_hazard_stall and old_EX_MEM.instr is not None and instr_writes_rd(old_EX_MEM.instr):
                    mem_rd = old_EX_MEM.instr.rd
                    if mem_rd is not None and mem_rd != 0:
                        if instr.rs1 == mem_rd or instr.rs2 == mem_rd:
                            data_hazard_stall = True
                            self.metrics.data_hazards += 1
                            self.metrics.stalls += 1
            
            # CON UNIDAD DE RIESGOS: solo hazard de carga-uso (lw seguido de uso inmediato)
            elif self.hazard_policy in (HazardPolicy.WITH_HAZARD_UNIT, HazardPolicy.FULL_HAZARD):
                if old_ID_EX.instr is not None and old_ID_EX.instr.opcode == "lw":
                    lw_instr = old_ID_EX.instr
                    lw_rd = lw_instr.rd
                    if lw_rd is not None and lw_rd != 0:
                        uses_rs1 = (instr.rs1 == lw_rd)
                        uses_rs2 = (instr.rs2 == lw_rd)
                        if uses_rs1 or uses_rs2:
                            load_use_stall = True
                            self.metrics.data_hazards += 1
                            self.metrics.stalls += 1

            if branch_taken:
                # Se tomó un branch en EX: vaciamos esta etapa (flush)
                self.metrics.control_hazards += 1
                pass  # new_ID_EX sigue siendo NOP
            elif load_use_stall or data_hazard_stall:
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
            print(f"[{self.name}] Pipeline vacío, programa terminado.")
            print(f"[{self.name}] Métricas finales: CPI={self.metrics.cpi:.2f}, Stalls={self.metrics.stalls}, Branch Accuracy={self.metrics.branch_accuracy:.1f}%")

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
            print(f"[{self.name}] Se alcanzó max_cycles, posible loop infinito.")
        else:
            print(f"[{self.name}] Ejecución completa en {cycles} ciclos.")

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
            "metrics": {
                "cycles": self.metrics.cycles,
                "instructions": self.metrics.instructions_executed,
                "cpi": self.metrics.cpi,
                "stalls": self.metrics.stalls,
                "branch_mispredictions": self.metrics.branch_mispredictions,
                "correct_predictions": self.metrics.correct_predictions,
                "branch_accuracy": self.metrics.branch_accuracy,
                "data_hazards": self.metrics.data_hazards,
                "control_hazards": self.metrics.control_hazards,
                "latencia": self.metrics.cycles * self.latency,
            },
            "hazard_policy": self.hazard_policy.name,
        }




    ########## ProcessorDiagramWidget
    # instructions:
    # add, sub, addi, and, or, lw, sw, beq, bne, jal
    # Hazard Policies:
        # HazardPolicy.NO_HAZARD_UNIT
        # HazardPolicy.WITH_HAZARD_UNIT
        # HazardPolicy.WITH_BRANCH_PRED
        # HazardPolicy.FULL_HAZARD
    def get_mux_and_enablers_states(self):
        fetch_muxes = [0, 0]
        # [PC_select, 2_4_select]   // 2_4_select will always be zero.
        execute_muxes = [1,1,1,0]   # execute_muxes[1] and execute_muxes[3] are always present and connect directly to the ALU.
        writeback_mux = [1]         # defaults to choosing ALU.
        write_enable_registers = [0]    # defaults to not enabled.
        write_enable_memory = [0]       # defaults to not enabled.

        # self.IF_ID.instr    # instruction in IF → ID buffer
        # self.ID_EX.instr    # instruction in ID → EX buffer
        # self.EX_MEM.instr   # instruction in EX → MEM buffer
        # self.MEM_WB.instr   # instruction in MEM → WB buffer
    
        # unnecessary to check hazard policy.
        # The difference in the muxes is taken into account by not drawing those not present.
        # If There is forwarding, execute muxes are different and there are 4.
        # if self.hazard_policy in (HazardPolicy.FULL_HAZARD, HazardPolicy.WITH_HAZARD_UNIT):
    
        # Execute muxes
        if self.ID_EX.instr is not None and self.ID_EX.instr.opcode in ("add", "sub", "and", "or", "addi", "lw", "sw", "beq", "bne", "jal"):
            execute_muxes = [1,1,1,0]
            # Forward from memory.
            forward_op1_or_op2_from_memory = detect_forwarding(self.ID_EX.instr, self.EX_MEM.instr) 
            if forward_op1_or_op2_from_memory[0]:
                execute_muxes[0] = 2    # op1 forward from mem.
            if forward_op1_or_op2_from_memory[1]:
                execute_muxes[2] = 2    # op2 forward from mem.
            # Forward from writeback.
            forward_op1_or_op2_from_writeback = detect_forwarding(self.ID_EX.instr, self.MEM_WB.instr) 
            if forward_op1_or_op2_from_writeback[0]:
                execute_muxes[0] = 0    # op1 forward from WB.
            if forward_op1_or_op2_from_writeback[1]:
                execute_muxes[2] = 0    # op2 forward from WB.
        if self.ID_EX.instr is not None and self.ID_EX.instr.opcode in ("addi", "sw"):   # if using immediate.
            execute_muxes[3] = 1

        if self.ID_EX.instr is not None and self.ID_EX.instr.opcode in ("beq", "bne", "jal"):    # If jumping
            # Decode mux 1
            execute_muxes[1] = 0    # op1 becomes PC+4.
            # Fetch mux
            fetch_muxes[1] = 1      # Chose ALU result for next PC.

        # Writeback mux
        if self.MEM_WB.instr is not None and self.MEM_WB.instr.opcode == "jal":
            writeback_mux[0] = 0  # Selects PC+4.
        if self.MEM_WB.instr is not None and self.MEM_WB.instr.opcode == "lw":
            writeback_mux[0] = 2  # Selects Memory.

        # Write Enable of Register File
        if self.MEM_WB.instr is not None and self.MEM_WB.instr.opcode in ("add", "sub", "and", "or", "addi", "lw"):   # If writing to a register.
            write_enable_registers[0] = 1
        # Write Enable of Data Memory
        if self.MEM_WB.instr is not None and self.MEM_WB.instr.opcode == "sw":   # If writing to a register.
            write_enable_memory[0] = 1

        resulting_mux_selection_list = fetch_muxes + execute_muxes + writeback_mux + write_enable_registers + write_enable_memory

        # Add current instrucctions to the resulting list.
        resulting_mux_selection_list += generate_pipes_instructions_list_for_print(self)
        print("At get_mux_and_enablers_states resulting_mux_selection_list = ", resulting_mux_selection_list)
        return resulting_mux_selection_list

    ########## ProcessorDiagramWidget

# returns a (boolean, boolean) value telling if op1 and op2 must be forwarded.
def detect_forwarding(execute_instruction: Instruction, memory_or_writeback_instruction: Instruction):
    if execute_instruction is not None:
        if memory_or_writeback_instruction is not None:
            return (execute_instruction.rs1 == memory_or_writeback_instruction.rd, execute_instruction.rs2 == memory_or_writeback_instruction.rd)
    return (False, False)
            

# # Registros de pipeline
# self.IF_ID = IF_ID_Reg()
# self.ID_EX = ID_EX_Reg()
# self.EX_MEM = EX_MEM_Reg()
# self.MEM_WB = MEM_WB_Reg()
def generate_pipes_instructions_list_for_print(processor):
    result = []
    if processor.IF_ID.instr is not None:
        result += [processor.IF_ID.instr.text]
    else:
        result += ["nop"]
        
    if processor.ID_EX.instr is not None:
        result += [processor.ID_EX.instr.text]
    else:
        result += ["nop"]
        
    if processor.EX_MEM.instr is not None:
        result += [processor.EX_MEM.instr.text]
    else:
        result += ["nop"]
        
    if processor.MEM_WB.instr is not None:
        result += [processor.MEM_WB.instr.text]
    else:
        result += ["nop"]
    return result
