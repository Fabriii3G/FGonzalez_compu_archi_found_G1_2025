import sys
from pathlib import Path
from dataclasses import dataclass
from datetime import datetime
from typing import List

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QPlainTextEdit, QWidget,
    QVBoxLayout, QHBoxLayout, QToolBar, QFileDialog, QMessageBox,
    QSplitter, QLabel, QTextEdit, QStackedWidget, QGroupBox, QFrame, QToolButton,
    QComboBox, QTableWidget, QTableWidgetItem, QHeaderView, QPushButton, QTabWidget
)
from PySide6.QtGui import (
    QAction, QActionGroup, QColor, QPainter, QTextFormat,
    QFont, QSyntaxHighlighter, QTextCharFormat, QPixmap
)
from PySide6.QtCore import Qt, QRect, QSize, QRegularExpression, QTimer

from simulator import Simulator, HazardPolicy, ExecutionMetrics



EDITOR_PLAIN_STYLE = """
QPlainTextEdit {
    background-color: #f7f7f7;
    color: #1e1e1e;
    selection-background-color: #c0d8ff;
    border: 1px solid #cccccc;
}
"""


# ============================================================
# Widget de diagrama del procesador.
# ============================================================
###########
class ProcessorDiagramWidget(QWidget):
    def __init__(self, simulator, parent=None):
        super().__init__(parent)
        self.sim = simulator        # reference to Simulator
        self.has_forwarding = False
        if self.sim.hazard_policy in (HazardPolicy.WITH_HAZARD_UNIT, HazardPolicy.FULL_HAZARD):
            self.image = QPixmap("diagrama_procesador_full_hazard.png")  # your screenshot
            self.has_forwarding = True
        else:
            self.image = QPixmap("diagrama_procesador_sin_forwarding.png")  # your screenshot
        # self.setMinimumSize(self.image.size())
        self.original_width = self.image.width()
        self.original_height = self.image.height()




    # def paintEvent(self, event):
    #     painter = QPainter(self)


    #     # Pick a max width for the diagram (fits nicely)
    #     max_width = min(self.width(), 900)

    #     scaled = self.image.scaled(
    #     max_width,
    #     max_width * self.image.height() / self.image.width(),
    #     Qt.KeepAspectRatio,
    #     Qt.SmoothTransformation
    #     )

    #     # Center horizontally
    #     x = (self.width() - scaled.width()) // 2
    #     painter.drawPixmap(x, 0, scaled)

    #     # Example: draw multiplexer selection numbers
    #     # You will supply (x, y) coordinates for each MUX
    #     mux_positions = [
    #         (120, 80),   # MUX 0 coordinates
    #         (300, 150),  # MUX 1
    #         # ...
    #     ]

    #     # Get the multiplexer states from the simulator
    #     # (You must define the attributes based on your simulation.)
    #     selected_channels = self.sim.get_mux_and_enablers_states()
    #     # this returns fetch_muxes + execute_muxes + writeback_mux + write_enable_registers + write_enable_memory

    #     painter.setPen(Qt.red)
    #     painter.setFont(QFont("Arial", 14, QFont.Bold))

    #     for i, (x, y) in enumerate(mux_positions):
    #         if i < len(selected_channels):
    #             painter.drawText(x, y, str(selected_channels[i]))



    def paintEvent(self, event):
        painter = QPainter(self)

        # Pick a max width for the diagram (fits nicely)
        max_width = min(self.width(), 900)

        scaled = self.image.scaled(
            max_width,
            max_width * self.image.height() / self.image.width(),
            Qt.KeepAspectRatio,
            Qt.SmoothTransformation
        )

        # Center horizontally (y stays at 0)
        x_offset = (self.width() - scaled.width()) // 2
        y_offset = 0

        # Draw scaled image
        painter.drawPixmap(x_offset, y_offset, scaled)

        # Draw MUX states
        if self.has_forwarding:
            mux_positions = [
                (107, 130),         # Fetch muxes
                (53, 267),          # Fetch muxes
                (808, 240),         # Execute muxes
                (863, 226),         # Execute muxes
                (795, 307),         # Execute muxes
                (877, 363),         # Execute muxes
                (1440, 281),        # Writeback mux
                (508, 308),         # Write Enable Reg File
                (1167, 350),        # Write Enable Memory.
                (336, 492),         # instruction in Decode pipe.
                (693, 492),        # instruction in Execute pipe.
                (1091, 492),         # instruction in Memory pipe.
                (1352, 492)         # instruction in Writeback pipe.
                # ...
            ]
        else:
                mux_positions = [
                (147, 130),         # Fetch muxes
                (106, 269),          # Fetch muxes
                (808, 240),         # Execute muxes
                (862, 240),         # Execute muxes
                (795, 307),         # Execute muxes
                (876, 351),         # Execute muxes
                (1468, 268),        # Writeback mux
                (576, 309),         # Write Enable Reg File
                (1195, 378),        # Write Enable Memory.
                (390, 492),         # instruction in Decode pipe.
                (761, 492),        # instruction in Execute pipe.
                (1105, 492),         # instruction in Memory pipe.
                (1380, 492)         # instruction in Writeback pipe.
                # ...
            ]

        # resulting_mux_selection_list = fetch_muxes + execute_muxes + writeback_mux + write_enable_registers + write_enable_memory
        selected_channels = self.sim.get_mux_and_enablers_states()

        painter.setPen(Qt.black)
        painter.setFont(QFont("Courier New", 8, QFont.Bold))

        # Compute scaling factors
        scale_x = scaled.width() / self.original_width
        scale_y = scaled.height() / self.original_height

        for i, (orig_x, orig_y) in enumerate(mux_positions):
            if i < len(selected_channels) and not((i==2 or i==4) and (self.sim.hazard_policy in (HazardPolicy.NO_HAZARD_UNIT, HazardPolicy.WITH_BRANCH_PRED))):

                # Scale original positions
                sx = int(orig_x * scale_x) + x_offset
                sy = int(orig_y * scale_y) + y_offset

                painter.drawText(sx, sy, str(selected_channels[i]))


############





# ============================================================
# Historial de ejecuciones
# ============================================================
@dataclass
class ExecutionRecord:
    """Registro de una ejecución completa con dos simuladores"""
    timestamp: str
    program_name: str
    sim1_policy: str
    sim2_policy: str
    sim1_metrics: ExecutionMetrics
    sim2_metrics: ExecutionMetrics


class ExecutionHistory:
    """Mantiene las últimas 10 ejecuciones"""
    def __init__(self, max_records: int = 10):
        self.max_records = max_records
        self.records: List[ExecutionRecord] = []
    
    def add_record(self, record: ExecutionRecord):
        self.records.insert(0, record)  # Agregar al inicio
        if len(self.records) > self.max_records:
            self.records = self.records[:self.max_records]
    
    def get_records(self) -> List[ExecutionRecord]:
        return self.records


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





















# # ============================================================
# # Vista gráfica del procesador (solo visual, sin lógica)
# # ============================================================
# class ProcessorView(QWidget):
#     """
#     Vista tipo diagrama: 5-stage RISC-V Processor.
#     Por ahora solo cajas estáticas, luego podemos colorearlas según uso.
#     """
#     def __init__(self, parent=None):
#         super().__init__(parent)

#         layout = QVBoxLayout(self)
#         layout.setContentsMargins(16, 16, 16, 16)
#         layout.setSpacing(16)

#         title = QLabel("5-stage RISC-V Processor")
#         title.setStyleSheet("font-weight: bold; font-size: 16px;")
#         layout.addWidget(title)

#         # Contenedor principal de etapas
#         stages_layout = QHBoxLayout()
#         stages_layout.setSpacing(20)
#         layout.addLayout(stages_layout)

#         # Helper para crear cada etapa
#         def make_stage(title_text: str, blocks: list[str]) -> QGroupBox:
#             g = QGroupBox(title_text)
#             g.setStyleSheet("""
#                 QGroupBox {
#                     border: 1px solid #999999;
#                     border-radius: 4px;
#                     margin-top: 8px;
#                     font-weight: bold;
#                 }
#                 QGroupBox::title {
#                     subcontrol-origin: margin;
#                     left: 8px;
#                     top: -2px;
#                 }
#             """)
#             v = QVBoxLayout(g)
#             v.setContentsMargins(8, 16, 8, 8)
#             v.setSpacing(8)

#             for b in blocks:
#                 frame = QFrame()
#                 frame.setFrameShape(QFrame.Box)
#                 frame.setStyleSheet("""
#                     QFrame {
#                         background-color: #f8f9fa;
#                         border: 1px solid #bbbbbb;
#                     }
#                 """)
#                 frame_layout = QVBoxLayout(frame)
#                 frame_layout.setContentsMargins(4, 4, 4, 4)
#                 label = QLabel(b)
#                 label.setAlignment(Qt.AlignCenter)
#                 frame_layout.addWidget(label)
#                 v.addWidget(frame)

#             v.addStretch(1)
#             return g

#         # Etapas inspiradas en Ripes
#         if_stage = make_stage("IF", ["PC", "Instruction memory", "IF/ID"])
#         id_stage = make_stage("ID", ["Decode", "Register file", "ID/EX"])
#         ex_stage = make_stage("EX", ["ALU", "Branch unit", "EX/MEM"])
#         mem_stage = make_stage("MEM", ["Data memory", "MEM/WB"])
#         wb_stage = make_stage("WB", ["Write-back mux"])

#         stages_layout.addWidget(if_stage)
#         stages_layout.addWidget(id_stage)
#         stages_layout.addWidget(ex_stage)
#         stages_layout.addWidget(mem_stage)
#         stages_layout.addWidget(wb_stage)

#         stages_layout.addStretch(1)


# ============================================================
# Vista gráfica del procesador (solo visual, sin lógica)
# ============================================================
class ProcessorView(QWidget):
    def __init__(self, simulator1, simulator2, parent=None):
        super().__init__(parent)

        layout = QVBoxLayout(self)
        
        # title = QLabel("Diagramas del Procesador (Simulador 1 y 2)")
        # title.setStyleSheet("font-weight: bold; font-size: 16px;")
        # layout.addWidget(title)

        diagrams_layout = QVBoxLayout()
        layout.addLayout(diagrams_layout)

        # Two processor diagrams
        self.diagram1 = ProcessorDiagramWidget(simulator1)
        self.diagram2 = ProcessorDiagramWidget(simulator2)

        diagrams_layout.addWidget(self.diagram1)
        diagrams_layout.addWidget(self.diagram2)

        diagrams_layout.setSpacing(20)


















# ============================================================
# Ventana principal
# ============================================================
class MiniIDEWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("RISC-V Pipeline Mini IDE - Dual Execution")
        self.resize(1400, 800)

        # --- Simuladores (dos versiones ejecutándose simultáneamente) ---
        self.simulator1 = Simulator(HazardPolicy.NO_HAZARD_UNIT, "Simulador 1")
        self.simulator2 = Simulator(HazardPolicy.WITH_HAZARD_UNIT, "Simulador 2")
        
        # --- Historial de ejecuciones ---
        self.execution_history = ExecutionHistory(max_records=10)
        self.current_program_name = "Programa sin nombre"

        # --- Auto-step ---
        self.auto_timer = QTimer(self)
        self.auto_timer.timeout.connect(self._on_auto_step_tick)
        self.btn_auto_step: QToolButton | None = None

        # --- Central stack: Editor / Processor / History ---
        self.central_stack = QStackedWidget()
        self.editor_page = None  # se inicializan en _create_pages
        self.processor_page = None
        self.history_page = None

        # Crear UI
        self._create_toolbar()
        self._create_pages()
        self._create_side_toolbar()

        self.statusBar().showMessage("Listo - Modo ejecución dual")
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
        
        toolbar.addSeparator()
        
        # ---------- Grupo: Políticas de Riesgos (lado a lado) ----------
        policy_widget = QWidget()
        policy_layout = QHBoxLayout(policy_widget)
        policy_layout.setContentsMargins(4, 0, 4, 0)
        policy_layout.setSpacing(15)
        
        # Simulador 1
        sim1_container = QWidget()
        sim1_layout = QVBoxLayout(sim1_container)
        sim1_layout.setContentsMargins(0, 0, 0, 0)
        sim1_layout.setSpacing(2)
        
        sim1_label = QLabel("Simulador 1:")
        sim1_label.setStyleSheet("font-size: 10px; font-weight: bold;")
        sim1_layout.addWidget(sim1_label)
        
        self.combo_sim1_policy = QComboBox()
        self.combo_sim1_policy.addItem("a) Sin unidad de riesgos", HazardPolicy.NO_HAZARD_UNIT)
        self.combo_sim1_policy.addItem("b) Con unidad de riesgos", HazardPolicy.WITH_HAZARD_UNIT)
        self.combo_sim1_policy.addItem("c) Con predicción de saltos", HazardPolicy.WITH_BRANCH_PRED)
        self.combo_sim1_policy.addItem("d) Con riesgos + predicción", HazardPolicy.FULL_HAZARD)
        self.combo_sim1_policy.setCurrentIndex(0)
        self.combo_sim1_policy.currentIndexChanged.connect(self._on_policy1_changed)
        self.combo_sim1_policy.setToolTip(
            "a) Sin forwarding ni predicción (muchos stalls)\n"
            "b) Con forwarding + detección (menos stalls)\n"
            "c) Solo predicción de saltos (sin forwarding)\n"
            "d) Forwarding + detección + predicción (óptimo)"
        )
        sim1_layout.addWidget(self.combo_sim1_policy)
        
        policy_layout.addWidget(sim1_container)
        
        # Simulador 2
        sim2_container = QWidget()
        sim2_layout = QVBoxLayout(sim2_container)
        sim2_layout.setContentsMargins(0, 0, 0, 0)
        sim2_layout.setSpacing(2)
        
        sim2_label = QLabel("Simulador 2:")
        sim2_label.setStyleSheet("font-size: 10px; font-weight: bold;")
        sim2_layout.addWidget(sim2_label)
        
        self.combo_sim2_policy = QComboBox()
        self.combo_sim2_policy.addItem("a) Sin unidad de riesgos", HazardPolicy.NO_HAZARD_UNIT)
        self.combo_sim2_policy.addItem("b) Con unidad de riesgos", HazardPolicy.WITH_HAZARD_UNIT)
        self.combo_sim2_policy.addItem("c) Con predicción de saltos", HazardPolicy.WITH_BRANCH_PRED)
        self.combo_sim2_policy.addItem("d) Con riesgos + predicción", HazardPolicy.FULL_HAZARD)
        self.combo_sim2_policy.setCurrentIndex(1)
        self.combo_sim2_policy.currentIndexChanged.connect(self._on_policy2_changed)
        self.combo_sim2_policy.setToolTip(
            "a) Sin forwarding ni predicción (muchos stalls)\n"
            "b) Con forwarding + detección (menos stalls)\n"
            "c) Solo predicción de saltos (sin forwarding)\n"
            "d) Forwarding + detección + predicción (óptimo)"
        )
        sim2_layout.addWidget(self.combo_sim2_policy)
        
        policy_layout.addWidget(sim2_container)
        
        toolbar.addWidget(policy_widget)

    def _on_policy1_changed(self, index):
        """Cambiar política del simulador 1"""
        policy = self.combo_sim1_policy.currentData()
        self.simulator1 = Simulator(policy, "Simulador 1")
        self.statusBar().showMessage(f"Simulador 1: {self.combo_sim1_policy.currentText()}")
    
    def _on_policy2_changed(self, index):
        """Cambiar política del simulador 2"""
        policy = self.combo_sim2_policy.currentData()
        self.simulator2 = Simulator(policy, "Simulador 2")
        self.statusBar().showMessage(f"Simulador 2: {self.combo_sim2_policy.currentText()}")

    def _create_side_toolbar(self):
        """
        Barra lateral izquierda para alternar entre:
        - Editor
        - Processor (vista gráfica)
        - Historial
        """
        side = QToolBar("View Toolbar")
        side.setOrientation(Qt.Vertical)
        side.setMovable(False)
        self.addToolBar(Qt.LeftToolBarArea, side)

        grp = QActionGroup(self)
        grp.setExclusive(True)

        self.act_view_editor = QAction("Editor", self, checkable=True)
        self.act_view_processor = QAction("Procesador", self, checkable=True)
        self.act_view_history = QAction("Historial", self, checkable=True)

        grp.addAction(self.act_view_editor)
        grp.addAction(self.act_view_processor)
        grp.addAction(self.act_view_history)

        self.act_view_editor.setChecked(True)

        self.act_view_editor.triggered.connect(
            lambda _: self._switch_view(0)
        )
        self.act_view_processor.triggered.connect(
            lambda _: self._switch_view(1)
        )
        self.act_view_history.triggered.connect(
            lambda _: self._switch_view(2)
        )

        side.addAction(self.act_view_editor)
        side.addAction(self.act_view_processor)
        side.addAction(self.act_view_history)

    def _switch_view(self, index: int):
        self.central_stack.setCurrentIndex(index)

    # ----------------------------------------------------------------------
    # Páginas centrales: Editor, Processor y History
    # ----------------------------------------------------------------------
    def _create_pages(self):
        # --- Página 0: Editor + panel de simulación DUAL ---
        self.editor_page = QWidget()
        editor_layout = QVBoxLayout(self.editor_page)
        editor_layout.setContentsMargins(0, 0, 0, 0)

        splitter = FixedSplitter(Qt.Horizontal)

        # Editor
        self.editor = CodeEditor()
        self.editor.setPlaceholderText("# Escribe aquí tu código RISC-V...")
        splitter.addWidget(self.editor)

        # Panel derecho de simulación DUAL (con tabs)
        right_panel = QWidget()
        right_panel.setFixedWidth(500)

        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(8, 8, 8, 8)
        right_layout.setSpacing(8)

        self.lbl_title = QLabel("Panel de simulación dual")
        self.lbl_title.setStyleSheet("font-weight: bold; font-size: 14px;")
        right_layout.addWidget(self.lbl_title)

        self.lbl_status = QLabel("Estado: sin programa cargado")
        self.lbl_status.setWordWrap(True)
        right_layout.addWidget(self.lbl_status)

        # Tabs para cada simulador
        self.sim_tabs = QTabWidget()
        
        # Tab 1: Simulador 1
        self.sim1_widget = QWidget()
        sim1_layout = QVBoxLayout(self.sim1_widget)
        sim1_layout.setContentsMargins(4, 4, 4, 4)
        
        self.txt_pipeline1 = QPlainTextEdit()
        self.txt_pipeline1.setReadOnly(True)
        self.txt_pipeline1.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_pipeline1.setMaximumHeight(180)
        sim1_layout.addWidget(QLabel("Pipeline / Métricas:"))
        sim1_layout.addWidget(self.txt_pipeline1)
        
        self.txt_regs1 = QPlainTextEdit()
        self.txt_regs1.setReadOnly(True)
        self.txt_regs1.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_regs1.setMaximumHeight(150)
        sim1_layout.addWidget(QLabel("Registros:"))
        sim1_layout.addWidget(self.txt_regs1)
        
        self.txt_mem1 = QPlainTextEdit()
        self.txt_mem1.setReadOnly(True)
        self.txt_mem1.setStyleSheet(EDITOR_PLAIN_STYLE)
        sim1_layout.addWidget(QLabel("Memoria:"))
        sim1_layout.addWidget(self.txt_mem1)
        
        self.sim_tabs.addTab(self.sim1_widget, "Simulador 1")
        
        # Tab 2: Simulador 2
        self.sim2_widget = QWidget()
        sim2_layout = QVBoxLayout(self.sim2_widget)
        sim2_layout.setContentsMargins(4, 4, 4, 4)
        
        self.txt_pipeline2 = QPlainTextEdit()
        self.txt_pipeline2.setReadOnly(True)
        self.txt_pipeline2.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_pipeline2.setMaximumHeight(180)
        sim2_layout.addWidget(QLabel("Pipeline / Métricas:"))
        sim2_layout.addWidget(self.txt_pipeline2)
        
        self.txt_regs2 = QPlainTextEdit()
        self.txt_regs2.setReadOnly(True)
        self.txt_regs2.setStyleSheet(EDITOR_PLAIN_STYLE)
        self.txt_regs2.setMaximumHeight(150)
        sim2_layout.addWidget(QLabel("Registros:"))
        sim2_layout.addWidget(self.txt_regs2)
        
        self.txt_mem2 = QPlainTextEdit()
        self.txt_mem2.setReadOnly(True)
        self.txt_mem2.setStyleSheet(EDITOR_PLAIN_STYLE)
        sim2_layout.addWidget(QLabel("Memoria:"))
        sim2_layout.addWidget(self.txt_mem2)
        
        self.sim_tabs.addTab(self.sim2_widget, "Simulador 2")
        
        # Tab 3: Comparación (tabla)
        self.compare_widget = QWidget()
        compare_layout = QVBoxLayout(self.compare_widget)
        compare_layout.setContentsMargins(4, 4, 4, 4)
        
        compare_title = QLabel("Comparación de métricas")
        compare_title.setStyleSheet("font-weight: bold; font-size: 12px;")
        compare_layout.addWidget(compare_title)
        
        # Tabla de comparación
        self.compare_table = QTableWidget()
        self.compare_table.setColumnCount(4)
        self.compare_table.setHorizontalHeaderLabels(["Métrica", "Simulador 1", "Simulador 2", "Diferencia"])
        self.compare_table.horizontalHeader().setStretchLastSection(True)
        self.compare_table.setAlternatingRowColors(True)
        self.compare_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.compare_table.setStyleSheet("""
            QTableWidget {
                background-color: #f7f7f7;
                gridline-color: #cccccc;
                border: 1px solid #cccccc;
            }
            QTableWidget::item {
                padding: 4px;
                color: #000000;
            }
            QHeaderView::section {
                background-color: #e9ecef;
                padding: 6px;
                border: 1px solid #adb5bd;
                font-weight: bold;
                color: #000000;
            }
        """)
        compare_layout.addWidget(self.compare_table)
        
        # Análisis textual
        self.txt_analysis = QTextEdit()
        self.txt_analysis.setReadOnly(True)
        self.txt_analysis.setMaximumHeight(80)
        self.txt_analysis.setStyleSheet(EDITOR_PLAIN_STYLE)
        compare_layout.addWidget(QLabel("Análisis:"))
        compare_layout.addWidget(self.txt_analysis)
        
        self.sim_tabs.addTab(self.compare_widget, "Comparación")
        
        right_layout.addWidget(self.sim_tabs)

        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 0)

        editor_layout.addWidget(splitter)

        # --- Página 1: ProcessorView (diagrama gráfico) ---
        # self.processor_page = ProcessorView()
        self.processor_page = ProcessorView(self.simulator1, self.simulator2)

        
        # --- Página 2: History (historial de ejecuciones) ---
        self.history_page = self._create_history_page()

        # ########## ProcessorDiagramWidget
        # self.processor_view1 = ProcessorDiagramWidget(self.simulator1)
        # self.central_stack.addWidget(self.processor_view1)

        # ########## ProcessorDiagramWidget


        # Añadir al stack
        self.central_stack.addWidget(self.editor_page)     # index 0
        self.central_stack.addWidget(self.processor_page)  # index 1
        self.central_stack.addWidget(self.history_page)    # index 2

        self.setCentralWidget(self.central_stack)
    
    def _create_history_page(self):
        """Crear página de historial de ejecuciones"""
        history_widget = QWidget()
        layout = QVBoxLayout(history_widget)
        layout.setContentsMargins(16, 16, 16, 16)
        
        title = QLabel("Historial de ejecuciones (últimas 10)")
        title.setStyleSheet("font-weight: bold; font-size: 16px;")
        layout.addWidget(title)
        
        # Tabla de historial
        self.history_table = QTableWidget()
        self.history_table.setColumnCount(11)
        self.history_table.setHorizontalHeaderLabels([
            "Fecha/Hora", "Programa",
            "Sim1: Política", "Sim1: Ciclos", "Sim1: CPI", "Sim1: Stalls",
            "Sim2: Política", "Sim2: Ciclos", "Sim2: CPI", "Sim2: Stalls",
            "Diferencia CPI"
        ])
        self.history_table.horizontalHeader().setStretchLastSection(True)
        self.history_table.setAlternatingRowColors(True)
        layout.addWidget(self.history_table)
        
        # Botón para limpiar historial
        btn_clear = QPushButton("Limpiar historial")
        btn_clear.clicked.connect(self._clear_history)
        layout.addWidget(btn_clear)
        
        return history_widget
    
    def _clear_history(self):
        """Limpiar el historial de ejecuciones"""
        self.execution_history.records.clear()
        self._update_history_table()
        self.statusBar().showMessage("Historial limpiado")

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
            if not self.simulator1.program_loaded or (self.simulator1.halted and self.simulator2.halted):
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
        if not self.simulator1.program_loaded or (self.simulator1.halted and self.simulator2.halted):
            self._stop_auto_step()
            self._update_state_view()
            if self.simulator1.halted and self.simulator2.halted:
                self._add_to_history()
            return

        try:
            if not self.simulator1.halted:
                self.simulator1.step()
            if not self.simulator2.halted:
                self.simulator2.step()
            self._update_state_view()
        except Exception as e:
            self._stop_auto_step()
            QMessageBox.critical(self, "Error en auto-step", str(e))

    # ----------------------------------------------------------------------
    # Actualizar panel derecho
    # ----------------------------------------------------------------------
    def _update_state_view(self):
        """Actualizar vistas de ambos simuladores"""
        self._update_simulator_view(self.simulator1, self.txt_pipeline1, self.txt_regs1, self.txt_mem1)
        self._update_simulator_view(self.simulator2, self.txt_pipeline2, self.txt_regs2, self.txt_mem2)
        # # TODO: Add uppdate of processor widget.
        # # Widget de diagrama del procesador.
        # self.processor_view1.update()   # TODO: SUS
        if self.processor_page:
            self.processor_page.diagram1.update()
            self.processor_page.diagram2.update()

        self._update_comparison_view()

    def _update_simulator_view(self, simulator, txt_pipeline, txt_regs, txt_mem):
        """Actualizar vista de un simulador específico"""
        if not simulator.program_loaded:
            txt_pipeline.setPlainText("[Sin programa cargado]")
            txt_regs.setPlainText("[Registros no disponibles]")
            txt_mem.setPlainText("[Memoria no disponible]")
            return

        state = simulator.get_state()
        pc = state.get("pc", 0)
        halted = state.get("halted", False)
        cycle = state.get("cycle", 0)
        regs = state.get("registers", [])
        data_mem = state.get("data_memory", {})
        pipeline = state.get("pipeline", {})
        metrics = state.get("metrics", {})

        # Pipeline / estado con métricas
        lines = [
            f"Política: {state.get('hazard_policy', 'N/A')}",
            f"Ciclo: {cycle}",
            f"PC de fetch: {pc}",
            f"Estado: {'terminado' if halted else 'ejecutando'}",
            "",
            "=== MÉTRICAS ===",
            f"Instrucciones: {metrics.get('instructions', 0)}",
            f"CPI: {metrics.get('cpi', 0.0):.2f}",
            f"Stalls: {metrics.get('stalls', 0)}",
            f"Data Hazards: {metrics.get('data_hazards', 0)}",
            f"Control Hazards: {metrics.get('control_hazards', 0)}",
            f"Branch Mispred: {metrics.get('branch_mispredictions', 0)}",
            f"Branch Correct: {metrics.get('correct_predictions', 0)}",
            f"Branch Accuracy: {metrics.get('branch_accuracy', 0.0):.1f}%",
            "",
            "=== PIPELINE ===",
        ]
        stage_labels = [
            ("IF", "IF"),
            ("ID", "ID"),
            ("EX", "EX"),
            ("MEM", "MEM"),
            ("WB", "WB"),
        ]
        for key, label in stage_labels:
            info = pipeline.get(key, {})
            opcode = info.get("opcode")
            text = info.get("text")
            if opcode is None:
                lines.append(f"{label}: [NOP]")
            else:
                instr_str = text if text else opcode
                lines.append(f"{label}: {instr_str}")

        # Guardar posición del scroll antes de actualizar
        scrollbar = txt_pipeline.verticalScrollBar()
        scroll_pos = scrollbar.value()

        txt_pipeline.setPlainText("\n".join(lines))

        # Restaurar posición del scroll
        scrollbar.setValue(scroll_pos)

        # Registros (compacto)
        if regs and len(regs) == 32:
            reg_lines = []
            for i in range(0, 32, 4):
                line = f"x{i:02d}={regs[i]:4d} x{i+1:02d}={regs[i+1]:4d} x{i+2:02d}={regs[i+2]:4d} x{i+3:02d}={regs[i+3]:4d}"
                reg_lines.append(line)
            txt_regs.setPlainText("\n".join(reg_lines))
        else:
            txt_regs.setPlainText("[Registros no disponibles]")

        # Memoria
        if data_mem:
            mem_lines = [f"[{addr}] = {data_mem[addr]}" for addr in sorted(data_mem.keys())]
            mem_text = "\n".join(mem_lines)
        else:
            mem_text = "(Sin celdas de memoria usadas todavía)"

        txt_mem.setPlainText(mem_text)
    
    def _update_comparison_view(self):
        """Actualizar vista de comparación entre simuladores con tabla"""
        if not self.simulator1.program_loaded or not self.simulator2.program_loaded:
            self.compare_table.setRowCount(1)
            self.compare_table.setItem(0, 0, QTableWidgetItem("Sin programa cargado"))
            self.compare_table.setSpan(0, 0, 1, 4)
            self.txt_analysis.setHtml("<i>Ambos simuladores deben tener un programa cargado</i>")
            return
        
        state1 = self.simulator1.get_state()
        state2 = self.simulator2.get_state()
        
        m1 = state1.get("metrics", {})
        m2 = state2.get("metrics", {})
        
        # Datos para la tabla
        metrics_data = [
            ("Política", state1.get('hazard_policy', 'N/A'), state2.get('hazard_policy', 'N/A'), ""),
            ("Ciclos totales", str(m1.get('cycles', 0)), str(m2.get('cycles', 0)), 
             f"{m2.get('cycles', 0) - m1.get('cycles', 0):+d}"),
            ("Tiempo total (ns)", str(m1.get('latencia', 0)), str(m2.get('latencia', 0)), 
            f"{m2.get('latencia', 0) - m1.get('latencia', 0):+d}"),
            ("Instrucciones", str(m1.get('instructions', 0)), str(m2.get('instructions', 0)), 
             f"{m2.get('instructions', 0) - m1.get('instructions', 0):+d}"),
            ("CPI", f"{m1.get('cpi', 0.0):.3f}", f"{m2.get('cpi', 0.0):.3f}", 
             f"{m2.get('cpi', 0.0) - m1.get('cpi', 0.0):+.3f}"),
            ("Stalls", str(m1.get('stalls', 0)), str(m2.get('stalls', 0)), 
             f"{m2.get('stalls', 0) - m1.get('stalls', 0):+d}"),
            ("Data Hazards", str(m1.get('data_hazards', 0)), str(m2.get('data_hazards', 0)), 
             f"{m2.get('data_hazards', 0) - m1.get('data_hazards', 0):+d}"),
            ("Control Hazards", str(m1.get('control_hazards', 0)), str(m2.get('control_hazards', 0)), 
             f"{m2.get('control_hazards', 0) - m1.get('control_hazards', 0):+d}"),
            ("Branch Mispred.", str(m1.get('branch_mispredictions', 0)), str(m2.get('branch_mispredictions', 0)), 
             f"{m2.get('branch_mispredictions', 0) - m1.get('branch_mispredictions', 0):+d}"),
            ("Branch Accuracy %", f"{m1.get('branch_accuracy', 0.0):.1f}%", f"{m2.get('branch_accuracy', 0.0):.1f}%", 
             f"{m2.get('branch_accuracy', 0.0) - m1.get('branch_accuracy', 0.0):+.1f}%"),
        ]
        
        # Llenar la tabla
        self.compare_table.setRowCount(len(metrics_data))
        
        for row, (metric, val1, val2, diff) in enumerate(metrics_data):
            # Métrica
            item_metric = QTableWidgetItem(metric)
            item_metric.setFont(QFont("", -1, QFont.Bold))
            self.compare_table.setItem(row, 0, item_metric)
            
            # Simulador 1
            item_sim1 = QTableWidgetItem(val1)
            item_sim1.setBackground(QColor(231, 245, 255))  # Azul claro
            self.compare_table.setItem(row, 1, item_sim1)
            
            # Simulador 2
            item_sim2 = QTableWidgetItem(val2)
            item_sim2.setBackground(QColor(211, 249, 216))  # Verde claro
            self.compare_table.setItem(row, 2, item_sim2)
            
            # Diferencia (colorear según si es mejor o peor)
            if diff and metric != "Política":
                item_diff = QTableWidgetItem(diff)
                
                # Colorear diferencias (para CPI, menor es mejor; para otros, depende)
                if metric == "CPI":
                    # Verde si Sim2 tiene menor CPI (negativo)
                    if m2.get('cpi', 0.0) < m1.get('cpi', 0.0):
                        item_diff.setBackground(QColor(180, 255, 180))  # Verde
                        item_diff.setForeground(QColor(0, 100, 0))
                    elif m2.get('cpi', 0.0) > m1.get('cpi', 0.0):
                        item_diff.setBackground(QColor(255, 180, 180))  # Rojo
                        item_diff.setForeground(QColor(150, 0, 0))
                elif metric in ["Stalls", "Data Hazards", "Control Hazards", "Branch Mispred."]:
                    # Verde si Sim2 tiene menos (negativo)
                    if "-" in diff:
                        item_diff.setBackground(QColor(180, 255, 180))
                        item_diff.setForeground(QColor(0, 100, 0))
                    elif "+" in diff and diff != "+0":
                        item_diff.setBackground(QColor(255, 180, 180))
                        item_diff.setForeground(QColor(150, 0, 0))
                elif metric == "Branch Accuracy %":
                    # Verde si Sim2 tiene mayor accuracy (positivo)
                    if "+" in diff and diff != "+0.0%":
                        item_diff.setBackground(QColor(180, 255, 180))
                        item_diff.setForeground(QColor(0, 100, 0))
                    elif "-" in diff:
                        item_diff.setBackground(QColor(255, 180, 180))
                        item_diff.setForeground(QColor(150, 0, 0))
                
                self.compare_table.setItem(row, 3, item_diff)
            else:
                self.compare_table.setItem(row, 3, QTableWidgetItem("—"))
        
        # Ajustar ancho de columnas
        self.compare_table.resizeColumnsToContents()
        
        # Análisis textual en HTML
        cpi_diff = m2.get('cpi', 0.0) - m1.get('cpi', 0.0)
        cycle_diff = m2.get('cycles', 0) - m1.get('cycles', 0)
        
        analysis_html = "<b>Análisis:</b><br>"
        
        if abs(cpi_diff) < 0.01:
            analysis_html += "• Ambos simuladores tienen <b>CPI similar</b><br>"
        elif cpi_diff > 0:
            analysis_html += f"• <span style='color: #2b8a3e;'>Simulador 1</span> es más eficiente (CPI menor en <b>{abs(cpi_diff):.3f}</b>)<br>"
        else:
            analysis_html += f"• <span style='color: #2b8a3e;'>Simulador 2</span> es más eficiente (CPI menor en <b>{abs(cpi_diff):.3f}</b>)<br>"
        
        if cycle_diff != 0:
            analysis_html += f"• Diferencia de <b>{abs(cycle_diff)}</b> ciclos entre simuladores<br>"
        
        stall_diff = m2.get('stalls', 0) - m1.get('stalls', 0)
        if stall_diff != 0:
            if stall_diff < 0:
                analysis_html += f"• Simulador 2 reduce stalls en <b>{abs(stall_diff)}</b> ciclos<br>"
            else:
                analysis_html += f"• Simulador 1 reduce stalls en <b>{abs(stall_diff)}</b> ciclos<br>"
        
        self.txt_analysis.setHtml(analysis_html)

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
        self.simulator1.reset()
        self.simulator2.reset()
        self.current_program_name = "Programa sin nombre"
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
            self.current_program_name = Path(path).name
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
            self.simulator1.load_program_from_source(source)
            self.simulator2.load_program_from_source(source)
            self.lbl_status.setText("Estado: programa cargado en ambos simuladores")
            self.statusBar().showMessage("Programa cargado en ambos simuladores")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error al cargar programa", str(e))

    def on_reset(self):
        self._stop_auto_step()
        try:
            self.simulator1.reset()
            self.simulator2.reset()
            self.lbl_status.setText("Estado: simuladores reseteados")
            self.statusBar().showMessage("Simuladores reseteados")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en reset", str(e))

    def on_step(self):
        self._stop_auto_step()
        try:
            self.simulator1.step()
            self.simulator2.step()
            self.statusBar().showMessage("Step ejecutado en ambos simuladores")
            self._update_state_view()
        except Exception as e:
            QMessageBox.critical(self, "Error en step", str(e))

    def on_run(self):
        self._stop_auto_step()
        try:
            self.simulator1.run()
            self.simulator2.run()
            self.statusBar().showMessage("Ejecución completa en ambos simuladores")
            self._update_state_view()
            
            # Agregar al historial
            self._add_to_history()
        except Exception as e:
            QMessageBox.critical(self, "Error en run", str(e))
    
    def _add_to_history(self):
        """Agregar ejecución actual al historial"""
        if not self.simulator1.halted or not self.simulator2.halted:
            return
        
        record = ExecutionRecord(
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            program_name=self.current_program_name,
            sim1_policy=self.combo_sim1_policy.currentText(),
            sim2_policy=self.combo_sim2_policy.currentText(),
            sim1_metrics=ExecutionMetrics(
                cycles=self.simulator1.metrics.cycles,
                instructions_executed=self.simulator1.metrics.instructions_executed,
                stalls=self.simulator1.metrics.stalls,
                branch_mispredictions=self.simulator1.metrics.branch_mispredictions,
                correct_predictions=self.simulator1.metrics.correct_predictions,
                data_hazards=self.simulator1.metrics.data_hazards,
                control_hazards=self.simulator1.metrics.control_hazards,
            ),
            sim2_metrics=ExecutionMetrics(
                cycles=self.simulator2.metrics.cycles,
                instructions_executed=self.simulator2.metrics.instructions_executed,
                stalls=self.simulator2.metrics.stalls,
                branch_mispredictions=self.simulator2.metrics.branch_mispredictions,
                correct_predictions=self.simulator2.metrics.correct_predictions,
                data_hazards=self.simulator2.metrics.data_hazards,
                control_hazards=self.simulator2.metrics.control_hazards,
            )
        )
        
        self.execution_history.add_record(record)
        self._update_history_table()
    
    def _update_history_table(self):
        """Actualizar tabla de historial"""
        records = self.execution_history.get_records()
        self.history_table.setRowCount(len(records))
        
        for row, record in enumerate(records):
            self.history_table.setItem(row, 0, QTableWidgetItem(record.timestamp))
            self.history_table.setItem(row, 1, QTableWidgetItem(record.program_name))
            
            # Simulador 1
            self.history_table.setItem(row, 2, QTableWidgetItem(record.sim1_policy))
            self.history_table.setItem(row, 3, QTableWidgetItem(str(record.sim1_metrics.cycles)))
            self.history_table.setItem(row, 4, QTableWidgetItem(f"{record.sim1_metrics.cpi:.2f}"))
            self.history_table.setItem(row, 5, QTableWidgetItem(str(record.sim1_metrics.stalls)))
            
            # Simulador 2
            self.history_table.setItem(row, 6, QTableWidgetItem(record.sim2_policy))
            self.history_table.setItem(row, 7, QTableWidgetItem(str(record.sim2_metrics.cycles)))
            self.history_table.setItem(row, 8, QTableWidgetItem(f"{record.sim2_metrics.cpi:.2f}"))
            self.history_table.setItem(row, 9, QTableWidgetItem(str(record.sim2_metrics.stalls)))
            
            # Diferencia
            cpi_diff = record.sim2_metrics.cpi - record.sim1_metrics.cpi
            item = QTableWidgetItem(f"{cpi_diff:+.2f}")
            # Colorear según si es mejor o peor
            if cpi_diff < 0:
                item.setBackground(QColor(200, 255, 200))  # Verde claro
            elif cpi_diff > 0:
                item.setBackground(QColor(255, 200, 200))  # Rojo claro
            self.history_table.setItem(row, 10, item)


def main():
    app = QApplication(sys.argv)
    window = MiniIDEWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
