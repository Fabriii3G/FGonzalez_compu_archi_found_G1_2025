import sys
from pathlib import Path

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QPlainTextEdit, QWidget,
    QVBoxLayout, QToolBar, QFileDialog, QMessageBox,
    QSplitter, QLabel, QTextEdit
)
from PySide6.QtGui import QAction, QColor, QPainter, QTextFormat, QFont, QSyntaxHighlighter, QTextCharFormat
from PySide6.QtCore import Qt, QRect, QSize, QRegularExpression

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
        # Aritméticas: add, sub, addi, and, or
        self.rules.append({
            "pattern": QRegularExpression(r"\b(add|sub|addi|and|or)\b"),
            "format": arith_fmt,
        })

        # Branches: beq, bne, jal
        self.rules.append({
            "pattern": QRegularExpression(r"\b(beq|bne|jal)\b"),
            "format": branch_fmt,
        })

        # Memoria: lw, sw
        self.rules.append({
            "pattern": QRegularExpression(r"\b(lw|sw)\b"),
            "format": mem_fmt,
        })

        # Comentarios: todo lo que sigue a # o //
        self.comment_patterns = [
            QRegularExpression(r"#.*$"),
            QRegularExpression(r"//.*$"),
        ]
        self.comment_format = comment_fmt

    def highlightBlock(self, text: str):
        # Reglas de instrucciones
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

        # Fuente tipo JetBrains Mono (o equivalente monoespaciada)
        font = QFont()
        font.setFamily("JetBrains Mono")   # si no está, Qt hace fallback
        font.setStyleHint(QFont.Monospace)
        font.setPointSize(11)
        self.setFont(font)

        # Widget lateral para números de línea
        self.line_number_area = LineNumberArea(self)

        # Conectar señales
        self.blockCountChanged.connect(self.update_line_number_area_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.cursorPositionChanged.connect(self.highlight_current_line)

        # Config inicial
        self.update_line_number_area_width(0)
        self.highlight_current_line()

        # Tabs con la nueva fuente
        self.setTabStopDistance(4 * self.fontMetrics().horizontalAdvance(' '))

        # Un poco de estilo tipo IDE (suave, sin irnos full dark)
        self.setStyleSheet(EDITOR_PLAIN_STYLE)

        # >>> Highlighter de RISC-V <<<
        self.highlighter = RiscVHighlighter(self.document())

    # ---- Cálculo ancho columna de números ----
    def line_number_area_width(self):
        digits = len(str(max(1, self.blockCount())))
        space = 3 + self.fontMetrics().horizontalAdvance('9') * digits
        return space

    def update_line_number_area_width(self, _):
        self.setViewportMargins(self.line_number_area_width(), 0, 0, 0)

    # ---- Redimensionar área de números cuando se cambia el tamaño ----
    def resizeEvent(self, event):
        super().resizeEvent(event)
        cr = self.contentsRect()
        self.line_number_area.setGeometry(
            QRect(cr.left(), cr.top(), self.line_number_area_width(), cr.height())
        )

    # ---- Pintar los números de línea ----
    def line_number_area_paint_event(self, event):
        painter = QPainter(self.line_number_area)
        # Fondo un poco más oscuro que el editor
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

    # ---- Actualizar scroll/redibujado de la zona de números ----
    def update_line_number_area(self, rect, dy):
        if dy != 0:
            self.line_number_area.scroll(0, dy)
        else:
            self.line_number_area.update(0, rect.y(), self.line_number_area.width(), rect.height())

        if rect.contains(self.viewport().rect()):
            self.update_line_number_area_width(0)

    # ---- Resaltar línea actual ----
    def highlight_current_line(self):
        extra_selections = []

        if not self.isReadOnly():
            selection = QTextEdit.ExtraSelection()

            line_color = QColor(232, 242, 254)  # azulito suave
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
# Ventana principal
# ============================================================
class MiniIDEWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("RISC-V Pipeline Mini IDE")
        self.resize(1200, 700)

        # --- Simulador ---
        self.simulator = Simulator()

        # --- Crear UI ---
        self._create_toolbar()
        self._create_central_widgets()
        self.statusBar().showMessage("Listo")

        self._update_state_view()

    # ----------------------------------------------------------------------
    # Toolbar
    # ----------------------------------------------------------------------
    def _create_toolbar(self):
        toolbar = QToolBar("Main Toolbar")
        toolbar.setMovable(False)
        self.addToolBar(toolbar)

        # Archivo
        act_new = QAction("Nuevo", self)
        act_new.triggered.connect(self.on_new)

        act_open = QAction("Abrir", self)
        act_open.triggered.connect(self.on_open)

        act_save = QAction("Guardar", self)
        act_save.triggered.connect(self.on_save)

        toolbar.addAction(act_new)
        toolbar.addAction(act_open)
        toolbar.addAction(act_save)

        toolbar.addSeparator()

        # Simulación
        act_load = QAction("Cargar en simulador", self)
        act_load.triggered.connect(self.on_load_program)

        act_reset = QAction("Reset", self)
        act_reset.triggered.connect(self.on_reset)

        act_step = QAction("Step", self)
        act_step.triggered.connect(self.on_step)

        act_run = QAction("Run", self)
        act_run.triggered.connect(self.on_run)

        toolbar.addAction(act_load)
        toolbar.addAction(act_reset)
        toolbar.addAction(act_step)
        toolbar.addAction(act_run)

    # ----------------------------------------------------------------------
    # Zona central: editor + panel derecho en un QSplitter
    # ----------------------------------------------------------------------
    def _create_central_widgets(self):
        splitter = FixedSplitter(Qt.Horizontal)

        # --- Editor (izquierda) ---
        self.editor = CodeEditor()
        self.editor.setPlaceholderText("# Escribe aquí tu código RISC-V...")
        splitter.addWidget(self.editor)

        # --- Panel de simulación (derecha) ---
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

        # ---- Título + contenido: Estado / PC ----
        self.lbl_pc_title = QLabel("Estado / PC")
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

        # Un espacio flexible al final
        right_layout.addStretch(1)

        splitter.addWidget(right_panel)

        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 0)

        self.setCentralWidget(splitter)

    # ----------------------------------------------------------------------
    # Actualizar panel derecho con el estado del simulador
    # ----------------------------------------------------------------------
    def _update_state_view(self):
        """
        Lee el estado del simulador (get_state) y actualiza los paneles.
        """
        # Si no hay programa cargado, mostramos algo básico
        if not self.simulator.program_loaded:
            self.txt_pipeline.setPlainText("[Sin programa cargado]")
            self.txt_regs.setPlainText("[Registros no disponibles]")
            self.txt_mem.setPlainText("[Memoria no disponible]")
            return

        state = self.simulator.get_state()
        pc = state.get("pc", 0)
        halted = state.get("halted", False)
        regs = state.get("registers", [])
        data_mem = state.get("data_memory", {})

        # --- "Pipeline" / Estado / PC ---
        pipeline_lines = [
            f"PC actual: {pc}",
            f"Estado halted: {'sí' if halted else 'no'}",
            "",
            "(Modelo secuencial todavía, sin pipeline de 5 etapas)",
        ]
        self.txt_pipeline.setPlainText("\n".join(pipeline_lines))

        # --- Registros x0..x31 ---
        if regs and len(regs) == 32:
            reg_lines = [f"x{i:02d} = {regs[i]}" for i in range(32)]
            self.txt_regs.setPlainText("\n".join(reg_lines))
        else:
            self.txt_regs.setPlainText("[Registros no disponibles]")

        # --- Memoria de datos usada ---
        if data_mem:
            lines = []
            for addr in sorted(data_mem.keys()):
                lines.append(f"[{addr}] = {data_mem[addr]}")
            mem_text = "\n".join(lines)
        else:
            mem_text = "(Sin celdas de memoria usadas todavía)"

        self.txt_mem.setPlainText(mem_text)

    # ----------------------------------------------------------------------
    # Acciones de archivo
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
        self.editor.clear()
        self.simulator.reset()
        self.lbl_status.setText("Estado: nuevo archivo")
        self.statusBar().showMessage("Nuevo archivo")
        self._update_state_view()

    def on_open(self):
        if not self._confirm_discard():
            return

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
    # Acciones de simulación
    # ----------------------------------------------------------------------
    def on_load_program(self):
        source = self.editor.toPlainText()
        try:
            self.simulator.load_program_from_source(source)
            self.lbl_status.setText("Estado: programa cargado en simulador")
            self.statusBar().showMessage("Programa cargado en simulador")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error al cargar programa", str(e))

    def on_reset(self):
        try:
            self.simulator.reset()
            self.lbl_status.setText("Estado: simulador reseteado")
            self.statusBar().showMessage("Simulador reseteado")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en reset", str(e))

    def on_step(self):
        try:
            self.simulator.step()
            self.statusBar().showMessage("Step ejecutado")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en step", str(e))

    def on_run(self):
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

main()
