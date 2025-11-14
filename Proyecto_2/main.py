import sys
from pathlib import Path

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QPlainTextEdit, QWidget,
    QVBoxLayout, QHBoxLayout, QToolBar, QFileDialog, QMessageBox,
    QSplitter, QLabel, QTextEdit, QStackedWidget, QGroupBox, QFrame, QToolButton
)
from PySide6.QtGui import (
    QAction, QActionGroup, QColor, QPainter, QTextFormat,
    QFont, QSyntaxHighlighter, QTextCharFormat
)
from PySide6.QtCore import Qt, QRect, QSize, QRegularExpression, QTimer

from simulator import Simulator

EDITOR_PLAIN_STYLE = """
QPlainTextEdit {
    background-color: #f7f7f7;
    color: #1e1e1e;
    selection-background-color: #c0d8ff;
    border: 1px solid #cccccc;
}
"""


# ============================================================
# Editor con numeración de líneas
# ============================================================
class LineNumberArea(QWidget):
    def __init__(self, editor):
        super().__init__(editor)
        self.code_editor = editor

    def sizeHint(self):
        return QSize(self.code_editor.line_number_area_width(), 0)

    def paintEvent(self, event):
        self.code_editor.line_number_area_paint_event(event)


class RiscVHighlighter(QSyntaxHighlighter):
    def __init__(self, document):
        super().__init__(document)

        self.rules = []

        # --- Formatos ---
        arith_fmt = QTextCharFormat()
        arith_fmt.setForeground(QColor("#1c7ed6"))  # azul claro

        branch_fmt = QTextCharFormat()
        branch_fmt.setForeground(QColor("#f08c00"))  # naranja

        mem_fmt = QTextCharFormat()
        mem_fmt.setForeground(QColor("#e0a800"))  # amarillo/dorado

        comment_fmt = QTextCharFormat()
        comment_fmt.setForeground(QColor("#808080"))  # gris para comentarios

        # --- Patrones ---
        self.rules.append({
            "pattern": QRegularExpression(r"\b(add|sub|addi|and|or)\b"),
            "format": arith_fmt,
        })

        self.rules.append({
            "pattern": QRegularExpression(r"\b(beq|bne|jal)\b"),
            "format": branch_fmt,
        })

        self.rules.append({
            "pattern": QRegularExpression(r"\b(lw|sw)\b"),
            "format": mem_fmt,
        })

        self.comment_patterns = [
            QRegularExpression(r"#.*$"),
            QRegularExpression(r"//.*$"),
        ]
        self.comment_format = comment_fmt

    def highlightBlock(self, text: str):
        # Instrucciones
        for rule in self.rules:
            it = rule["pattern"].globalMatch(text)
            while it.hasNext():
                match = it.next()
                start = match.capturedStart()
                length = match.capturedLength()
                self.setFormat(start, length, rule["format"])

        # Comentarios
        for pattern in self.comment_patterns:
            it = pattern.globalMatch(text)
            while it.hasNext():
                match = it.next()
                start = match.capturedStart()
                length = match.capturedLength()
                self.setFormat(start, length, self.comment_format)


class CodeEditor(QPlainTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)

        # Fuente tipo JetBrains Mono
        font = QFont()
        font.setFamily("JetBrains Mono")
        font.setStyleHint(QFont.Monospace)
        font.setPointSize(11)
        self.setFont(font)

        # Área de números de línea
        self.line_number_area = LineNumberArea(self)

        self.blockCountChanged.connect(self.update_line_number_area_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.cursorPositionChanged.connect(self.highlight_current_line)

        self.update_line_number_area_width(0)
        self.highlight_current_line()

        self.setTabStopDistance(4 * self.fontMetrics().horizontalAdvance(' '))

        self.setStyleSheet(EDITOR_PLAIN_STYLE)

        self.highlighter = RiscVHighlighter(self.document())

    def line_number_area_width(self):
        digits = len(str(max(1, self.blockCount())))
        space = 3 + self.fontMetrics().horizontalAdvance('9') * digits
        return space

    def update_line_number_area_width(self, _):
        self.setViewportMargins(self.line_number_area_width(), 0, 0, 0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        cr = self.contentsRect()
        self.line_number_area.setGeometry(
            QRect(cr.left(), cr.top(), self.line_number_area_width(), cr.height())
        )

    def line_number_area_paint_event(self, event):
        painter = QPainter(self.line_number_area)
        painter.fillRect(event.rect(), QColor(235, 235, 235))

        block = self.firstVisibleBlock()
        block_number = block.blockNumber()
        top = int(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        bottom = top + int(self.blockBoundingRect(block).height())

        while block.isValid() and top <= event.rect().bottom():
            if block.isVisible() and bottom >= event.rect().top():
                number = str(block_number + 1)
                painter.setPen(QColor(120, 120, 120))
                painter.drawText(
                    0,
                    top,
                    self.line_number_area.width() - 4,
                    self.fontMetrics().height(),
                    Qt.AlignRight | Qt.AlignVCenter,
                    number,
                )

            block = block.next()
            block_number += 1
            top = bottom
            bottom = top + int(self.blockBoundingRect(block).height())

    def update_line_number_area(self, rect, dy):
        if dy != 0:
            self.line_number_area.scroll(0, dy)
        else:
            self.line_number_area.update(0, rect.y(), self.line_number_area.width(), rect.height())

        if rect.contains(self.viewport().rect()):
            self.update_line_number_area_width(0)

    def highlight_current_line(self):
        extra_selections = []

        if not self.isReadOnly():
            selection = QTextEdit.ExtraSelection()
            line_color = QColor(232, 242, 254)
            selection.format.setBackground(line_color)
            selection.format.setProperty(QTextFormat.FullWidthSelection, True)
            selection.cursor = self.textCursor()
            selection.cursor.clearSelection()
            extra_selections.append(selection)

        self.setExtraSelections(extra_selections)


# ============================================================
# Splitter fijo (no se puede redimensionar con el mouse)
# ============================================================
class FixedSplitter(QSplitter):
    def __init__(self, orientation, parent=None):
        super().__init__(orientation, parent)
        self.setHandleWidth(0)
        self.setChildrenCollapsible(False)

    def createHandle(self):
        handle = super().createHandle()
        handle.setEnabled(False)
        return handle

    def mousePressEvent(self, event):
        event.ignore()

    def mouseMoveEvent(self, event):
        event.ignore()

    def mouseReleaseEvent(self, event):
        event.ignore()


# ============================================================
# Vista gráfica del procesador (solo visual, sin lógica)
# ============================================================
class ProcessorView(QWidget):
    """
    Vista tipo diagrama: 5-stage RISC-V Processor.
    Por ahora solo cajas estáticas, luego podemos colorearlas según uso.
    """
    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(16)

        title = QLabel("5-stage RISC-V Processor")
        title.setStyleSheet("font-weight: bold; font-size: 16px;")
        layout.addWidget(title)

        # Contenedor principal de etapas
        stages_layout = QHBoxLayout()
        stages_layout.setSpacing(20)
        layout.addLayout(stages_layout)

        # Helper para crear cada etapa
        def make_stage(title_text: str, blocks: list[str]) -> QGroupBox:
            g = QGroupBox(title_text)
            g.setStyleSheet("""
                QGroupBox {
                    border: 1px solid #999999;
                    border-radius: 4px;
                    margin-top: 8px;
                    font-weight: bold;
                }
                QGroupBox::title {
                    subcontrol-origin: margin;
                    left: 8px;
                    top: -2px;
                }
            """)
            v = QVBoxLayout(g)
            v.setContentsMargins(8, 16, 8, 8)
            v.setSpacing(8)

            for b in blocks:
                frame = QFrame()
                frame.setFrameShape(QFrame.Box)
                frame.setStyleSheet("""
                    QFrame {
                        background-color: #f8f9fa;
                        border: 1px solid #bbbbbb;
                    }
                """)
                frame_layout = QVBoxLayout(frame)
                frame_layout.setContentsMargins(4, 4, 4, 4)
                label = QLabel(b)
                label.setAlignment(Qt.AlignCenter)
                frame_layout.addWidget(label)
                v.addWidget(frame)

            v.addStretch(1)
            return g

        # Etapas inspiradas en Ripes
        if_stage = make_stage("IF", ["PC", "Instruction memory", "IF/ID"])
        id_stage = make_stage("ID", ["Decode", "Register file", "ID/EX"])
        ex_stage = make_stage("EX", ["ALU", "Branch unit", "EX/MEM"])
        mem_stage = make_stage("MEM", ["Data memory", "MEM/WB"])
        wb_stage = make_stage("WB", ["Write-back mux"])

        stages_layout.addWidget(if_stage)
        stages_layout.addWidget(id_stage)
        stages_layout.addWidget(ex_stage)
        stages_layout.addWidget(mem_stage)
        stages_layout.addWidget(wb_stage)

        stages_layout.addStretch(1)


# ============================================================
# Ventana principal
# ============================================================
class MiniIDEWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("RISC-V Pipeline Mini IDE")
        self.resize(1200, 700)

        # --- Simulador ---
        self.simulator = Simulator()

        # --- Auto-step ---
        self.auto_timer = QTimer(self)
        self.auto_timer.timeout.connect(self._on_auto_step_tick)
        self.btn_auto_step: QToolButton | None = None

        # --- Central stack: Editor / Processor ---
        self.central_stack = QStackedWidget()
        self.editor_page = None  # se inicializan en _create_pages
        self.processor_page = None

        # Crear UI
        self._create_toolbar()
        self._create_pages()
        self._create_side_toolbar()

        self.statusBar().showMessage("Listo")
        self._update_state_view()

    # ----------------------------------------------------------------------
    # Toolbars
    # ----------------------------------------------------------------------
    def _create_toolbar(self):
        toolbar = QToolBar("Main Toolbar")
        toolbar.setMovable(False)
        self.addToolBar(Qt.TopToolBarArea, toolbar)

        # Helper de estilo para botones de archivo
        def style_file_button(btn: QToolButton,
                              bg: str, hover: str, pressed: str, border: str):
            btn.setStyleSheet(f"""
                QToolButton {{
                    border-radius: 6px;
                    padding: 4px 10px;
                    border: 1px solid {border};
                    background-color: {bg};
                }}
                QToolButton:hover {{
                    background-color: {hover};
                }}
                QToolButton:pressed {{
                    background-color: {pressed};
                }}
            """)

        # Helper de estilo para botones de simulación
        def style_sim_button(btn: QToolButton,
                             bg: str, hover: str, pressed: str, border: str):
            btn.setStyleSheet(f"""
                QToolButton {{
                    border-radius: 6px;
                    padding: 4px 10px;
                    border: 1px solid {border};
                    background-color: {bg};
                }}
                QToolButton:hover {{
                    background-color: {hover};
                }}
                QToolButton:pressed {{
                    background-color: {pressed};
                }}
                QToolButton:checked {{
                    background-color: {pressed};
                }}
            """)

        # ---------- Grupo: Archivo ----------
        file_widget = QWidget()
        file_layout = QHBoxLayout(file_widget)
        file_layout.setContentsMargins(0, 0, 0, 0)
        file_layout.setSpacing(6)

        self.btn_new = QToolButton()
        self.btn_new.setText("🆕")
        self.btn_new.clicked.connect(self.on_new)
        style_file_button(
            self.btn_new,
            bg="#f1f3f5", hover="#e9ecef", pressed="#dee2e6", border="#868e96"
        )
        file_layout.addWidget(self.btn_new)

        self.btn_open = QToolButton()
        self.btn_open.setText("📂")
        self.btn_open.clicked.connect(self.on_open)
        style_file_button(
            self.btn_open,
            bg="#f1f3f5", hover="#e9ecef", pressed="#dee2e6", border="#868e96"
        )
        file_layout.addWidget(self.btn_open)

        self.btn_save = QToolButton()
        self.btn_save.setText("💾")
        self.btn_save.clicked.connect(self.on_save)
        style_file_button(
            self.btn_save,
            bg="#f1f3f5", hover="#e9ecef", pressed="#dee2e6", border="#868e96"
        )
        file_layout.addWidget(self.btn_save)

        self.btn_load = QToolButton()
        self.btn_load.setText("⮕ Cargar")
        self.btn_load.clicked.connect(self.on_load_program)
        style_file_button(
            self.btn_load,
            bg="#e7f5ff", hover="#d0ebff", pressed="#a5d8ff", border="#339af0"
        )
        file_layout.addWidget(self.btn_load)

        toolbar.addWidget(file_widget)

        toolbar.addSeparator()

        # ---------- Grupo: Simulación ----------
        sim_widget = QWidget()
        sim_layout = QHBoxLayout(sim_widget)
        sim_layout.setContentsMargins(0, 0, 0, 0)
        sim_layout.setSpacing(6)

        # Reset (⟲ gris)
        self.btn_reset = QToolButton()
        self.btn_reset.setText("⟲ Reset")
        self.btn_reset.clicked.connect(self.on_reset)
        style_sim_button(
            self.btn_reset,
            bg="#f1f3f5", hover="#e9ecef", pressed="#dee2e6", border="#868e96"
        )
        sim_layout.addWidget(self.btn_reset)

        # Step (⏱ azul)
        self.btn_step = QToolButton()
        self.btn_step.setText("⏱ Step")
        self.btn_step.clicked.connect(self.on_step)
        style_sim_button(
            self.btn_step,
            bg="#e7f5ff", hover="#d0ebff", pressed="#a5d8ff", border="#339af0"
        )
        sim_layout.addWidget(self.btn_step)

        # Auto-step (⏩ ámbar, toggle)
        self.btn_auto_step = QToolButton()
        self.btn_auto_step.setText("⏩ Auto-step")
        self.btn_auto_step.setCheckable(True)
        self.btn_auto_step.toggled.connect(self.on_toggle_auto_step)
        style_sim_button(
            self.btn_auto_step,
            bg="#fff3bf", hover="#ffec99", pressed="#ffe066", border="#f08c00"
        )
        sim_layout.addWidget(self.btn_auto_step)

        # Run (▶ verde)
        self.btn_run = QToolButton()
        self.btn_run.setText("▶ Run")
        self.btn_run.clicked.connect(self.on_run)
        style_sim_button(
            self.btn_run,
            bg="#d3f9d8", hover="#b2f2bb", pressed="#8ce99a", border="#37b24d"
        )
        sim_layout.addWidget(self.btn_run)

        toolbar.addWidget(sim_widget)

    def _create_side_toolbar(self):
        """
        Barra lateral izquierda para alternar entre:
        - Editor
        - Processor (vista gráfica)
        """
        side = QToolBar("View Toolbar")
        side.setOrientation(Qt.Vertical)
        side.setMovable(False)
        self.addToolBar(Qt.LeftToolBarArea, side)

        grp = QActionGroup(self)
        grp.setExclusive(True)

        self.act_view_editor = QAction("Editor", self, checkable=True)
        self.act_view_processor = QAction("Processor", self, checkable=True)

        grp.addAction(self.act_view_editor)
        grp.addAction(self.act_view_processor)

        self.act_view_editor.setChecked(True)

        self.act_view_editor.triggered.connect(
            lambda _: self._switch_view(0)
        )
        self.act_view_processor.triggered.connect(
            lambda _: self._switch_view(1)
        )

        side.addAction(self.act_view_editor)
        side.addAction(self.act_view_processor)

    def _switch_view(self, index: int):
        self.central_stack.setCurrentIndex(index)

    # ----------------------------------------------------------------------
    # Páginas centrales: Editor y Processor
    # ----------------------------------------------------------------------
    def _create_pages(self):
        # --- Página 0: Editor + panel de simulación ---
        self.editor_page = QWidget()
        editor_layout = QVBoxLayout(self.editor_page)
        editor_layout.setContentsMargins(0, 0, 0, 0)

        splitter = FixedSplitter(Qt.Horizontal)

        # Editor
        self.editor = CodeEditor()
        self.editor.setPlaceholderText("# Escribe aquí tu código RISC-V...")
        splitter.addWidget(self.editor)

        # Panel derecho de simulación
        right_panel = QWidget()
        right_panel.setFixedWidth(360)

        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(8, 8, 8, 8)
        right_layout.setSpacing(8)

        self.lbl_title = QLabel("Panel de simulación")
        self.lbl_title.setStyleSheet("font-weight: bold; font-size: 14px;")
        right_layout.addWidget(self.lbl_title)

        self.lbl_status = QLabel("Estado: sin programa cargado")
        self.lbl_status.setWordWrap(True)
        right_layout.addWidget(self.lbl_status)

        self.lbl_pc_title = QLabel("Estado / Pipeline (5 etapas)")
        self.lbl_pc_title.setStyleSheet("font-weight: bold; margin-top: 6px;")
        right_layout.addWidget(self.lbl_pc_title)

        self.txt_pipeline = QPlainTextEdit()
        self.txt_pipeline.setReadOnly(True)
        self.txt_pipeline.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_pipeline.setLineWrapMode(QPlainTextEdit.WidgetWidth)
        right_layout.addWidget(self.txt_pipeline)

        self.lbl_regs_title = QLabel("Registros")
        self.lbl_regs_title.setStyleSheet("font-weight: bold; margin-top: 6px;")
        right_layout.addWidget(self.lbl_regs_title)

        self.txt_regs = QPlainTextEdit()
        self.txt_regs.setReadOnly(True)
        self.txt_regs.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_regs.setLineWrapMode(QPlainTextEdit.NoWrap)
        right_layout.addWidget(self.txt_regs)

        self.lbl_mem_title = QLabel("Memoria de datos")
        self.lbl_mem_title.setStyleSheet("font-weight: bold; margin-top: 6px;")
        right_layout.addWidget(self.lbl_mem_title)

        self.txt_mem = QPlainTextEdit()
        self.txt_mem.setReadOnly(True)
        self.txt_mem.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_mem.setLineWrapMode(QPlainTextEdit.NoWrap)
        right_layout.addWidget(self.txt_mem)

        right_layout.addStretch(1)

        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 0)

        editor_layout.addWidget(splitter)

        # --- Página 1: ProcessorView (diagrama gráfico) ---
        self.processor_page = ProcessorView()

        # Añadir al stack
        self.central_stack.addWidget(self.editor_page)     # index 0
        self.central_stack.addWidget(self.processor_page)  # index 1

        self.setCentralWidget(self.central_stack)

    # ----------------------------------------------------------------------
    # Auto-step
    # ----------------------------------------------------------------------
    def _stop_auto_step(self):
        if self.auto_timer.isActive():
            self.auto_timer.stop()
        if self.btn_auto_step and self.btn_auto_step.isChecked():
            self.btn_auto_step.setChecked(False)

    def on_toggle_auto_step(self, checked: bool):
        if checked:
            if not self.simulator.program_loaded or self.simulator.halted:
                QMessageBox.information(
                    self,
                    "Auto-step",
                    "No hay programa cargado o ya terminó."
                )
                self.btn_auto_step.setChecked(False)
                return
            self.auto_timer.start(400)
            self.statusBar().showMessage("Auto-step: ejecutando...")
        else:
            self.auto_timer.stop()
            self.statusBar().showMessage("Auto-step detenido")

    def _on_auto_step_tick(self):
        if not self.simulator.program_loaded or self.simulator.halted:
            self._stop_auto_step()
            self._update_state_view()
            return

        try:
            self.simulator.step()
            self._update_state_view()
        except Exception as e:
            self._stop_auto_step()
            QMessageBox.critical(self, "Error en auto-step", str(e))

    # ----------------------------------------------------------------------
    # Actualizar panel derecho
    # ----------------------------------------------------------------------
    def _update_state_view(self):
        if not self.simulator.program_loaded:
            self.txt_pipeline.setPlainText("[Sin programa cargado]")
            self.txt_regs.setPlainText("[Registros no disponibles]")
            self.txt_mem.setPlainText("[Memoria no disponible]")
            return

        state = self.simulator.get_state()
        pc = state.get("pc", 0)
        halted = state.get("halted", False)
        cycle = state.get("cycle", 0)
        regs = state.get("registers", [])
        data_mem = state.get("data_memory", {})
        pipeline = state.get("pipeline", {})

        # Pipeline / estado
        lines = [
            f"Ciclo: {cycle}",
            f"PC de fetch: {pc}",
            f"Estado halted: {'sí' if halted else 'no'}",
            "",
        ]

        stage_labels = [
            ("IF", "IF  (Fetch)"),
            ("ID", "ID  (Decode)"),
            ("EX", "EX  (Execute)"),
            ("MEM", "MEM (Memory)"),
            ("WB", "WB  (Write Back)"),
        ]

        for key, label in stage_labels:
            info = pipeline.get(key, {})
            opcode = info.get("opcode")
            text = info.get("text")
            pc_stage = info.get("pc")
            if opcode is None:
                lines.append(f"{label}: [NOP]")
            else:
                pc_str = "-" if pc_stage is None else str(pc_stage)
                instr_str = text if text else opcode
                lines.append(f"{label}: PC={pc_str} | {instr_str}")

        self.txt_pipeline.setPlainText("\n".join(lines))

        # Registros
        if regs and len(regs) == 32:
            reg_lines = [f"x{i:02d} = {regs[i]}" for i in range(32)]
            self.txt_regs.setPlainText("\n".join(reg_lines))
        else:
            self.txt_regs.setPlainText("[Registros no disponibles]")

        # Memoria
        if data_mem:
            mem_lines = [f"[{addr}] = {data_mem[addr]}" for addr in sorted(data_mem.keys())]
            mem_text = "\n".join(mem_lines)
        else:
            mem_text = "(Sin celdas de memoria usadas todavía)"

        self.txt_mem.setPlainText(mem_text)

    # ----------------------------------------------------------------------
    # Archivo
    # ----------------------------------------------------------------------
    def _confirm_discard(self) -> bool:
        resp = QMessageBox.question(
            self,
            "Confirmar",
            "¿Deseas descartar el contenido actual?",
            QMessageBox.Yes | QMessageBox.No
        )
        return resp == QMessageBox.Yes

    def on_new(self):
        if not self._confirm_discard():
            return
        self._stop_auto_step()
        self.editor.clear()
        self.simulator.reset()
        self.lbl_status.setText("Estado: nuevo archivo")
        self.statusBar().showMessage("Nuevo archivo")
        self._update_state_view()

    def on_open(self):
        if not self._confirm_discard():
            return
        self._stop_auto_step()

        path, _ = QFileDialog.getOpenFileName(
            self,
            "Abrir archivo RISC-V",
            "",
            "RISC-V Assembly (*.s *.asm *.txt);;Todos los archivos (*)"
        )
        if not path:
            return

        try:
            content = Path(path).read_text(encoding="utf-8")
            self.editor.setPlainText(content)
            self.lbl_status.setText(f"Archivo abierto: {path}")
            self.statusBar().showMessage(f"Abierto: {path}")
        except Exception as e:
            QMessageBox.critical(self, "Error al abrir archivo", str(e))

    def on_save(self):
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Guardar archivo",
            "",
            "RISC-V Assembly (*.s);;Todos los archivos (*)"
        )
        if not path:
            return

        try:
            content = self.editor.toPlainText()
            Path(path).write_text(content, encoding="utf-8")
            self.lbl_status.setText(f"Archivo guardado: {path}")
            self.statusBar().showMessage(f"Guardado: {path}")
        except Exception as e:
            QMessageBox.critical(self, "Error al guardar archivo", str(e))

    # ----------------------------------------------------------------------
    # Simulación
    # ----------------------------------------------------------------------
    def on_load_program(self):
        self._stop_auto_step()
        source = self.editor.toPlainText()
        try:
            self.simulator.load_program_from_source(source)
            self.lbl_status.setText("Estado: programa cargado en simulador")
            self.statusBar().showMessage("Programa cargado en simulador")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error al cargar programa", str(e))

    def on_reset(self):
        self._stop_auto_step()
        try:
            self.simulator.reset()
            self.lbl_status.setText("Estado: simulador reseteado")
            self.statusBar().showMessage("Simulador reseteado")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en reset", str(e))

    def on_step(self):
        self._stop_auto_step()
        try:
            self.simulator.step()
            self.statusBar().showMessage("Step ejecutado")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en step", str(e))

    def on_run(self):
        self._stop_auto_step()
        try:
            self.simulator.run()
            self.statusBar().showMessage("Ejecución completa")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en run", str(e))


def main():
    app = QApplication(sys.argv)
    window = MiniIDEWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
