from typing import List, Dict
from instruction import Instruction


class AssemblerError(Exception):
    """Errores de ensamblado con info de línea."""
    pass


class Assembler:
    """
    Ensamblador sencillo para un subconjunto de RISC-V:
    add, sub, addi, and, or, lw, sw, beq, bne, jal
    """

    # --------------------------------------------------------
    # API pública principal
    # --------------------------------------------------------
    def assemble(self, source: str) -> List[Instruction]:
        """
        Ensambla código RISC-V (subset) en una lista de Instruction.

        Soporta:
          - Labels:  loop:
          - Instrucciones:
            add, sub, addi, and, or, lw, sw, beq, bne, jal
        """
        lines = source.splitlines()
        labels: Dict[str, int] = {}
        instruction_records = []  # (instr_text, line_number, address)

        current_addr = 0  # PC en bytes (0, 4, 8, ...)

        # ----- Primer pase: labels + texto de instrucciones -----
        for line_num, raw_line in enumerate(lines, start=1):
            # Quitar comentarios (soportamos # y //)
            line = raw_line.split("#", 1)[0]
            line = line.split("//", 1)[0]
            line = line.strip()

            if not line:
                continue  # línea vacía/comentario

            # Manejar labels (puede haber varias, y opcionalmente instrucción en la misma línea)
            while ":" in line:
                label, rest = line.split(":", 1)
                label = label.strip()
                if not label:
                    raise AssemblerError(f"Línea {line_num}: label vacío")
                if label in labels:
                    raise AssemblerError(f"Línea {line_num}: label duplicado '{label}'")
                labels[label] = current_addr
                line = rest.strip()
                if not line:
                    break  # solo había label en la línea

            if not line:
                continue  # solo labels en esta línea

            # Lo que queda es texto de instrucción
            instruction_records.append((line, line_num, current_addr))
            current_addr += 4

        # ----- Segundo pase: parsear cada instrucción -----
        instructions: List[Instruction] = []

        for text, line_num, addr in instruction_records:
            instr = self._parse_instruction(text, line_num, addr, labels)
            instructions.append(instr)

        return instructions

    # --------------------------------------------------------
    # Helpers de parseo
    # --------------------------------------------------------
    def _parse_register(self, token: str, line: int) -> int:
        """
        Convierte 'x0'..'x31' a índice entero 0..31.
        (Por ahora solo soportamos registros tipo xN).
        """
        token = token.strip()
        if not token.startswith("x"):
            raise AssemblerError(f"Línea {line}: registro inválido '{token}' (use x0..x31)")
        num_str = token[1:]
        if not num_str.isdigit():
            raise AssemblerError(f"Línea {line}: registro inválido '{token}'")
        reg = int(num_str)
        if not (0 <= reg <= 31):
            raise AssemblerError(f"Línea {line}: registro fuera de rango '{token}'")
        return reg

    def _parse_immediate(self, token: str, line: int) -> int:
        """
        Convierte un inmediato en entero. Soporta decimal y base automática
        (ej: 10, -5, 0x10).
        """
        token = token.strip()
        try:
            return int(token, 0)  # base 0 => detecta 0x, 0b, etc.
        except ValueError:
            raise AssemblerError(f"Línea {line}: inmediato inválido '{token}'")

    def _parse_instruction(
        self,
        text: str,
        line: int,
        addr: int,
        labels: Dict[str, int],
    ) -> Instruction:
        """
        Parsea una línea de instrucción (sin labels ni comentarios).
        """
        # Normalizar: separar comas y paréntesis
        # ej: "lw x1, 0(x2)" -> tokens: ["lw","x1","0","x2"]
        tmp = text.replace(",", " ")
        tmp = tmp.replace("(", " ")
        tmp = tmp.replace(")", " ")
        tokens = [t for t in tmp.split() if t]

        if not tokens:
            raise AssemblerError(f"Línea {line}: instrucción vacía")

        opcode = tokens[0].lower()

        # ---------- Instrucciones tipo R (add, sub, and, or) ----------
        if opcode in ("add", "sub", "and", "or"):
            if len(tokens) != 4:
                raise AssemblerError(
                    f"Línea {line}: sintaxis '{opcode} rd, rs1, rs2' esperada"
                )
            rd = self._parse_register(tokens[1], line)
            rs1 = self._parse_register(tokens[2], line)
            rs2 = self._parse_register(tokens[3], line)
            return Instruction(
                opcode=opcode,
                rd=rd,
                rs1=rs1,
                rs2=rs2,
                address=addr,
                line=line,
                text=text,
            )

        # ---------- Instrucción tipo I (addi) ----------
        if opcode == "addi":
            if len(tokens) != 4:
                raise AssemblerError(f"Línea {line}: sintaxis 'addi rd, rs1, imm' esperada")
            rd = self._parse_register(tokens[1], line)
            rs1 = self._parse_register(tokens[2], line)
            imm = self._parse_immediate(tokens[3], line)
            return Instruction(
                opcode=opcode,
                rd=rd,
                rs1=rs1,
                imm=imm,
                address=addr,
                line=line,
                text=text,
            )

        # ---------- Cargas/almacenamientos (lw, sw) ----------
        # lw rd, offset(rs1) -> tokens: [lw, rd, offset, rs1]
        if opcode == "lw":
            if len(tokens) != 4:
                raise AssemblerError(f"Línea {line}: sintaxis 'lw rd, offset(rs1)' esperada")
            rd = self._parse_register(tokens[1], line)
            imm = self._parse_immediate(tokens[2], line)
            rs1 = self._parse_register(tokens[3], line)
            return Instruction(
                opcode=opcode,
                rd=rd,
                rs1=rs1,
                imm=imm,
                address=addr,
                line=line,
                text=text,
            )

        # sw rs2, offset(rs1) -> tokens: [sw, rs2, offset, rs1]
        if opcode == "sw":
            if len(tokens) != 4:
                raise AssemblerError(f"Línea {line}: sintaxis 'sw rs2, offset(rs1)' esperada")
            rs2 = self._parse_register(tokens[1], line)
            imm = self._parse_immediate(tokens[2], line)
            rs1 = self._parse_register(tokens[3], line)
            return Instruction(
                opcode=opcode,
                rs1=rs1,
                rs2=rs2,
                imm=imm,
                address=addr,
                line=line,
                text=text,
            )

        # ---------- Branches (beq, bne) ----------
        # beq rs1, rs2, label
        if opcode in ("beq", "bne"):
            if len(tokens) != 4:
                raise AssemblerError(
                    f"Línea {line}: sintaxis '{opcode} rs1, rs2, label' esperada"
                )
            rs1 = self._parse_register(tokens[1], line)
            rs2 = self._parse_register(tokens[2], line)
            label = tokens[3]
            if label not in labels:
                raise AssemblerError(f"Línea {line}: label no definida '{label}'")
            target_addr = labels[label]
            return Instruction(
                opcode=opcode,
                rs1=rs1,
                rs2=rs2,
                target_addr=target_addr,
                address=addr,
                line=line,
                text=text,
            )

        # ---------- Salto (jal) ----------
        # jal rd, label   (ej: jal x1, func)
        if opcode == "jal":
            if len(tokens) != 3:
                raise AssemblerError(f"Línea {line}: sintaxis 'jal rd, label' esperada")
            rd = self._parse_register(tokens[1], line)
            label = tokens[2]
            if label not in labels:
                raise AssemblerError(f"Línea {line}: label no definida '{label}'")
            target_addr = labels[label]
            return Instruction(
                opcode=opcode,
                rd=rd,
                target_addr=target_addr,
                address=addr,
                line=line,
                text=text,
            )

        raise AssemblerError(f"Línea {line}: opcode no soportado '{opcode}'")
