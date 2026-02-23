$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "Ejecutando sin permisos de administrador" -ForegroundColor Yellow
    Write-Host "Algunas funciones pueden no estar disponibles" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# Cargar ensamblados necesarios
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Función para mover la ventana
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class MoveForm {
        [DllImport("user32.dll")]
        public static extern bool ReleaseCapture();
        [DllImport("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
    }
"@

# Clase para manejar estilos
class EstiloBsL {
    [string]$tipo
    [hashtable]$propiedades
    
    EstiloBsL([string]$linea) {
        $this.propiedades = @{}
        $this.ParsearEstilos($linea)
    }
    
    [void] ParsearEstilos([string]$linea) {
        $patron = 's\+([a-zA-Z0-9_]+)="([^"]*)"'
        $matches = [regex]::Matches($linea, $patron)
        
        foreach ($match in $matches) {
            $propiedad = $match.Groups[1].Value
            $valor = $match.Groups[2].Value
            $this.propiedades[$propiedad] = $valor
        }
    }
    
    [int] GetRadioBorde($control) {
        if ($this.propiedades.ContainsKey('circular')) {
            $valor = $this.propiedades['circular']
            if ($valor -match '(\d+)xp') {
                return [int]$matches[1]
            }
            elseif ($valor -match '(\d+)%') {
                $porcentaje = [int]$matches[1] / 100
                return [int]($control.Height * $porcentaje)
            }
            elseif ($valor -match '(\d+)') {
                return [int]$matches[1]
            }
        }
        return 0
    }
    
    [System.Drawing.Color] GetColor([string]$prop, [System.Drawing.Color]$defecto) {
        if ($this.propiedades.ContainsKey($prop)) {
            $colorStr = $this.propiedades[$prop]
            try {
                return [System.Drawing.ColorTranslator]::FromHtml($colorStr)
            } catch {
                try {
                    return [System.Drawing.Color]::FromName($colorStr)
                } catch {
                    return $defecto
                }
            }
        }
        return $defecto
    }
    
    [int] GetPadding([string]$prop, [int]$defecto) {
        if ($this.propiedades.ContainsKey($prop)) {
            $valor = $this.propiedades[$prop]
            if ($valor -match '(\d+)') {
                return [int]$matches[1]
            }
        }
        return $defecto
    }
    
    [string] GetString([string]$prop, [string]$defecto) {
        if ($this.propiedades.ContainsKey($prop)) {
            return $this.propiedades[$prop]
        }
        return $defecto
    }
    
    [bool] GetBoolean([string]$prop, [bool]$defecto) {
        if ($this.propiedades.ContainsKey($prop)) {
            $valor = $this.propiedades[$prop].ToLower()
            return ($valor -eq 'true' -or $valor -eq 'si' -or $valor -eq '1')
        }
        return $defecto
    }
    
    [System.Drawing.Font] GetFont([System.Drawing.Font]$fuenteBase) {
        $fuente = $fuenteBase
        $estilo = [System.Drawing.FontStyle]::Regular
        
        if ($this.propiedades.ContainsKey('negrita') -and $this.GetBoolean('negrita', $false)) {
            $estilo = $estilo -bor [System.Drawing.FontStyle]::Bold
        }
        if ($this.propiedades.ContainsKey('cursiva') -and $this.GetBoolean('cursiva', $false)) {
            $estilo = $estilo -bor [System.Drawing.FontStyle]::Italic
        }
        if ($this.propiedades.ContainsKey('subrayado') -and $this.GetBoolean('subrayado', $false)) {
            $estilo = $estilo -bor [System.Drawing.FontStyle]::Underline
        }
        
        $tamano = $fuente.Size
        if ($this.propiedades.ContainsKey('tamano')) {
            $tamanoStr = $this.propiedades['tamano']
            if ($tamanoStr -match '(\d+)') {
                $tamano = [int]$matches[1]
            }
        }
        
        return New-Object System.Drawing.Font($fuente.FontFamily, $tamano, $estilo)
    }
}

# Diccionario para almacenar referencias a controles por ID
$script:controles = @{}
$script:archivoActual = $null
$script:ejecutando = $false
$script:formularioActual = $null

# Crear formulario principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "Mi Lenguaje de Programación - [Nuevo Programa.mlp]"
$form.Size = New-Object System.Drawing.Size(1400, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = "#1e1e1e"
$form.FormBorderStyle = "None"

# ================= BARRA DE TITULO =================
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Height = 35
$titleBar.Dock = "Top"
$titleBar.BackColor = "#2d2d2d"
$titleBar.Cursor = "SizeAll"

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "  Mi Lenguaje de Programación - [Nuevo Programa.mlp]"
$titleLabel.ForeColor = "White"
$titleLabel.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(10, 8)
$titleLabel.Size = New-Object System.Drawing.Size(600, 20)
$titleLabel.Cursor = "SizeAll"
$titleBar.Controls.Add($titleLabel)

$form.Controls.Add($titleBar)

$minBtn = New-Object System.Windows.Forms.Button
$minBtn.Text = "--"
$minBtn.Size = New-Object System.Drawing.Size(25, 25)
$minBtn.FlatStyle = "Flat"
$minBtn.FlatAppearance.BorderSize = 0
$minBtn.BackColor = "#3a3a3a"
$minBtn.ForeColor = "White"
$minBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 90), 5)
$minBtn.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($minBtn)

$maxBtn = New-Object System.Windows.Forms.Button
$maxBtn.Text = "[]"
$maxBtn.Size = New-Object System.Drawing.Size(25, 25)
$maxBtn.FlatStyle = "Flat"
$maxBtn.FlatAppearance.BorderSize = 0
$maxBtn.BackColor = "#3a3a3a"
$maxBtn.ForeColor = "White"
$maxBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 60), 5)
$maxBtn.Add_Click({ 
    if ($form.WindowState -eq "Normal") { 
        $form.WindowState = "Maximized"
    } else { 
        $form.WindowState = "Normal"
    }
})
$titleBar.Controls.Add($maxBtn)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "X"
$closeBtn.Size = New-Object System.Drawing.Size(25, 25)
$closeBtn.FlatStyle = "Flat"
$closeBtn.FlatAppearance.BorderSize = 0
$closeBtn.BackColor = "#e81123"
$closeBtn.ForeColor = "White"
$closeBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 30), 5)
$closeBtn.Add_Click({ $form.Close() })
$titleBar.Controls.Add($closeBtn)

$titleBar.Add_MouseDown({
    if ($_.Button -eq "Left") {
        [MoveForm]::ReleaseCapture()
        [MoveForm]::SendMessage($form.Handle, 0x0112, 0xF010, 0)
    }
})

# ================= MENU PRINCIPAL =================
$menuStrip = New-Object System.Windows.Forms.MenuStrip
$menuStrip.BackColor = "#252526"
$menuStrip.ForeColor = "White"
$menuStrip.Font = New-Object System.Drawing.Font("Consolas", 10)

# Archivo
$archivoMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$archivoMenu.Text = "Archivo"
$archivoMenu.ForeColor = "White"

$nuevoItem = New-Object System.Windows.Forms.ToolStripMenuItem
$nuevoItem.Text = "Nuevo"
$nuevoItem.ShortcutKeyDisplayString = "Ctrl+N"
$nuevoItem.Add_Click({
    $editorTexto.Text = @'
bsl frame titulo="Mi Aplicacion" tamano="800,600"

    bsl imprimir>[Hola Mundo desde BsL!] bsl/imprimir
    
    bsl etiqueta texto="Bienvenido a BsL" posicion="20,20" s+color="cyan" s+tamano="24" s+negrita="true"
    
    bsl etiqueta texto="Texto con estilo" posicion="20,70" s+color="yellow" s+tamano="16" s+cursiva="true"
    
    bsl cajaTexto id="nombre" posicion="20,120" tamano="250,35" s+circular="15xp" s+colorfondo="#f0f0f0" s+borde="2" s+color="blue"
    
    bsl cajaTexto id="email" posicion="20,170" tamano="250,35" s+circular="10xp" s+colorfondo="#e8f0fe" s+placeholder="correo@ejemplo.com"
    
    bsl boton texto="Enviar" posicion="20,230" tamano="120,45" s+circular="25%" s+colorfondo="#4CAF50" s+color="white" s+tamano="14" s+negrita="true" s+sombra="true"
    
    bsl boton texto="Cancelar" posicion="160,230" tamano="120,45" s+circular="25%" s+colorfondo="#f44336" s+color="white" s+tamano="14" s+negrita="true"

bsl/frame
'@
    $script:archivoActual = $null
    $statusArchivo.Text = "Nuevo archivo"
    EscribirConsola "Nuevo archivo BsL creado"
})

$abrirItem = New-Object System.Windows.Forms.ToolStripMenuItem
$abrirItem.Text = "Abrir"
$abrirItem.ShortcutKeyDisplayString = "Ctrl+O"
$abrirItem.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Archivos BsL (*.bsl)|*.bsl|Todos los archivos (*.*)|*.*"
    
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $editorTexto.Text = [System.IO.File]::ReadAllText($dialog.FileName)
        $script:archivoActual = $dialog.FileName
        $statusArchivo.Text = [System.IO.Path]::GetFileName($dialog.FileName)
        EscribirConsola "Archivo cargado: $($dialog.FileName)"
    }
})

$guardarItem = New-Object System.Windows.Forms.ToolStripMenuItem
$guardarItem.Text = "Guardar"
$guardarItem.ShortcutKeyDisplayString = "Ctrl+S"
$guardarItem.Add_Click({
    if ($script:archivoActual) {
        [System.IO.File]::WriteAllText($script:archivoActual, $editorTexto.Text)
        EscribirConsola "Archivo guardado: $($script:archivoActual)"
    } else {
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "Archivos BsL (*.bsl)|*.bsl"
        $dialog.FileName = "programa.bsl"
        
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [System.IO.File]::WriteAllText($dialog.FileName, $editorTexto.Text)
            $script:archivoActual = $dialog.FileName
            $statusArchivo.Text = [System.IO.Path]::GetFileName($dialog.FileName)
            EscribirConsola "Archivo guardado como: $($dialog.FileName)"
        }
    }
})

$salirItem = New-Object System.Windows.Forms.ToolStripMenuItem
$salirItem.Text = "Salir"
$salirItem.Add_Click({ $form.Close() })

$archivoMenu.DropDownItems.AddRange(@($nuevoItem, $abrirItem, $guardarItem, $salirItem))

# Insertar
$insertarMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$insertarMenu.Text = "Insertar"
$insertarMenu.ForeColor = "White"

$insertFrame = New-Object System.Windows.Forms.ToolStripMenuItem
$insertFrame.Text = "Frame (ventana)"
$insertFrame.Add_Click({ InsertarBsL "frame" })

$insertImprimir = New-Object System.Windows.Forms.ToolStripMenuItem
$insertImprimir.Text = "Imprimir"
$insertImprimir.Add_Click({ InsertarBsL "imprimir" })

$insertBoton = New-Object System.Windows.Forms.ToolStripMenuItem
$insertBoton.Text = "Boton"
$insertBoton.Add_Click({ InsertarBsL "boton" })

$insertEtiqueta = New-Object System.Windows.Forms.ToolStripMenuItem
$insertEtiqueta.Text = "Etiqueta"
$insertEtiqueta.Add_Click({ InsertarBsL "etiqueta" })

$insertCaja = New-Object System.Windows.Forms.ToolStripMenuItem
$insertCaja.Text = "Caja texto"
$insertCaja.Add_Click({ InsertarBsL "cajatexto" })

$insertLista = New-Object System.Windows.Forms.ToolStripMenuItem
$insertLista.Text = "Lista"
$insertLista.Add_Click({ InsertarBsL "lista" })

$insertarMenu.DropDownItems.AddRange(@($insertFrame, $insertImprimir, $insertBoton, $insertEtiqueta, $insertCaja, $insertLista))

# Ejemplos
$ejemplosMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$ejemplosMenu.Text = "Ejemplos"
$ejemplosMenu.ForeColor = "White"

$ejemploHolaMundo = New-Object System.Windows.Forms.ToolStripMenuItem
$ejemploHolaMundo.Text = "Hola Mundo"
$ejemploHolaMundo.Add_Click({
    $editorTexto.Text = @'
bsl frame titulo="Hola Mundo" tamano="400,300"

    bsl imprimir>[Hola Mundo desde BsL!] bsl/imprimir
    
    bsl etiqueta texto="Mi primera aplicacion BsL" posicion="20,20" s+color="cyan" s+tamano="18" s+negrita="true"
    
    bsl boton texto="Saludar" posicion="20,70" tamano="120,40" s+circular="20xp" s+colorfondo="#2196F3" s+color="white" s+tamano="12"

bsl/frame
'@
})

$ejemploLogin = New-Object System.Windows.Forms.ToolStripMenuItem
$ejemploLogin.Text = "Pantalla Login"
$ejemploLogin.Add_Click({
    $editorTexto.Text = @'
bsl frame titulo="Inicio de Sesion" tamano="380,320"

    bsl imprimir>[Iniciando sesion...] bsl/imprimir
    
    bsl etiqueta texto="Iniciar Sesion" posicion="20,20" s+tamano="20" s+negrita="true" s+color="#333"
    
    bsl etiqueta texto="Usuario:" posicion="20,70" s+color="#555" s+tamano="12"
    bsl cajaTexto id="usuario" posicion="100,65" tamano="200,35" s+circular="8xp" s+colorfondo="#f9f9f9" s+borde="1" s+padding="10"
    
    bsl etiqueta texto="Contraseña:" posicion="20,120" s+color="#555" s+tamano="12"
    bsl cajaTexto id="password" posicion="100,115" tamano="200,35" s+circular="8xp" s+colorfondo="#f9f9f9" s+password="true" s+borde="1"
    
    bsl boton texto="Ingresar" posicion="100,170" tamano="120,40" s+circular="20xp" s+colorfondo="#4CAF50" s+color="white" s+tamano="14" s+negrita="true"
    
    bsl etiqueta texto="¿Olvidaste tu contraseña?" posicion="100,220" s+color="#2196F3" s+subrayado="true" s+tamano="10"

bsl/frame
'@
})

$ejemploCalculadora = New-Object System.Windows.Forms.ToolStripMenuItem
$ejemploCalculadora.Text = "Calculadora"
$ejemploCalculadora.Add_Click({
    $editorTexto.Text = @'
bsl frame titulo="Calculadora BsL" tamano="320,420"

    bsl imprimir>[Calculadora iniciada] bsl/imprimir
    
    bsl cajaTexto id="pantalla" posicion="20,20" tamano="260,50" s+circular="10xp" s+colorfondo="#222" s+color="white" s+alineacion="derecha" s+tamano="20" s+negrita="true"
    
    bsl boton texto="7" posicion="20,90" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16" s+negrita="true"
    bsl boton texto="8" posicion="85,90" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="9" posicion="150,90" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="/" posicion="215,90" tamano="55,55" s+circular="50%" s+colorfondo="#FF9800" s+color="white" s+tamano="18" s+negrita="true"
    
    bsl boton texto="4" posicion="20,155" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="5" posicion="85,155" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="6" posicion="150,155" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="*" posicion="215,155" tamano="55,55" s+circular="50%" s+colorfondo="#FF9800" s+color="white" s+tamano="18"
    
    bsl boton texto="1" posicion="20,220" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="2" posicion="85,220" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="3" posicion="150,220" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="-" posicion="215,220" tamano="55,55" s+circular="50%" s+colorfondo="#FF9800" s+color="white" s+tamano="18"
    
    bsl boton texto="0" posicion="20,285" tamano="120,55" s+circular="25xp" s+colorfondo="#666" s+color="white" s+tamano="16"
    bsl boton texto="." posicion="150,285" tamano="55,55" s+circular="50%" s+colorfondo="#666" s+color="white" s+tamano="18"
    bsl boton texto="=" posicion="215,285" tamano="55,55" s+circular="50%" s+colorfondo="#4CAF50" s+color="white" s+tamano="18" s+negrita="true"

bsl/frame
'@
})

$ejemplosMenu.DropDownItems.AddRange(@($ejemploHolaMundo, $ejemploLogin, $ejemploCalculadora))

$menuStrip.Items.AddRange(@($archivoMenu, $insertarMenu, $ejemplosMenu))
$form.Controls.Add($menuStrip)

# ================= TOOLBAR =================
$toolStrip = New-Object System.Windows.Forms.ToolStrip
$toolStrip.BackColor = "#333333"

$btnNuevo = New-Object System.Windows.Forms.ToolStripButton
$btnNuevo.Text = "Nuevo"
$btnNuevo.ForeColor = "White"
$btnNuevo.Add_Click({ $nuevoItem.PerformClick() })

$btnAbrir = New-Object System.Windows.Forms.ToolStripButton
$btnAbrir.Text = "Abrir"
$btnAbrir.ForeColor = "White"
$btnAbrir.Add_Click({ $abrirItem.PerformClick() })

$btnGuardar = New-Object System.Windows.Forms.ToolStripButton
$btnGuardar.Text = "Guardar"
$btnGuardar.ForeColor = "White"
$btnGuardar.Add_Click({ $guardarItem.PerformClick() })

$separator1 = New-Object System.Windows.Forms.ToolStripSeparator

$btnEjecutar = New-Object System.Windows.Forms.ToolStripButton
$btnEjecutar.Text = "Ejecutar (F5)"
$btnEjecutar.ForeColor = "White"
$btnEjecutar.BackColor = "#107c10"
$btnEjecutar.Add_Click({ EjecutarBsL })

$btnDetener = New-Object System.Windows.Forms.ToolStripButton
$btnDetener.Text = "Detener"
$btnDetener.ForeColor = "White"
$btnDetener.BackColor = "#d32f2f"
$btnDetener.Enabled = $false
$btnDetener.Add_Click({ DetenerBsL })

$toolStrip.Items.AddRange(@($btnNuevo, $btnAbrir, $btnGuardar, $separator1, $btnEjecutar, $btnDetener))
$form.Controls.Add($toolStrip)

# ================= PANEL PRINCIPAL CON SPLITTERS ARRASTRABLES =================
$mainContainer = New-Object System.Windows.Forms.SplitContainer
$mainContainer.Dock = "Fill"
$mainContainer.Orientation = "Vertical"
$mainContainer.SplitterDistance = 300
$mainContainer.BackColor = "#1e1e1e"
$mainContainer.Panel1.BackColor = "#252526"
$mainContainer.Panel2.BackColor = "#1e1e1e"
$form.Controls.Add($mainContainer)

# ================= PANEL IZQUIERDO - TEORÍA DE INSTRUCCIONES =================
$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Dock = "Fill"
$leftPanel.BackColor = "#252526"
$leftPanel.Padding = New-Object System.Windows.Forms.Padding(5)

$teoriaLabel = New-Object System.Windows.Forms.Label
$teoriaLabel.Text = "TEORÍA DE INSTRUCCIONES"
$teoriaLabel.Dock = "Top"
$teoriaLabel.Height = 30
$teoriaLabel.BackColor = "#2d2d2d"
$teoriaLabel.ForeColor = "#FFA500"
$teoriaLabel.TextAlign = "MiddleCenter"
$teoriaLabel.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$leftPanel.Controls.Add($teoriaLabel)

$treeInstrucciones = New-Object System.Windows.Forms.TreeView
$treeInstrucciones.Dock = "Fill"
$treeInstrucciones.BackColor = "#252526"
$treeInstrucciones.ForeColor = "White"
$treeInstrucciones.Font = New-Object System.Drawing.Font("Consolas", 10)
$treeInstrucciones.BorderStyle = "None"
$treeInstrucciones.ShowLines = $true
$treeInstrucciones.ShowRootLines = $true

$basico = $treeInstrucciones.Nodes.Add("BÁSICO")
$basico.Nodes.Add("var - Declarar variable")
$basico.Nodes.Add("if - Condicional")
$basico.Nodes.Add("while - Bucle")
$basico.Nodes.Add("for - Iteración")

$funciones = $treeInstrucciones.Nodes.Add("FUNCIONES")
$funciones.Nodes.Add("function - Definir función")
$funciones.Nodes.Add("return - Retornar valor")

$iosalida = $treeInstrucciones.Nodes.Add("ENTRADA/SALIDA")
$iosalida.Nodes.Add("print() - Mostrar texto")
$iosalida.Nodes.Add("input() - Leer entrada")

$gui = $treeInstrucciones.Nodes.Add("INTERFAZ GRÁFICA")
$gui.Nodes.Add("bsl frame - Crear ventana")
$gui.Nodes.Add("bsl etiqueta - Texto")
$gui.Nodes.Add("bsl boton - Botón")
$gui.Nodes.Add("bsl cajaTexto - Campo texto")
$gui.Nodes.Add("bsl lista - Lista")
$gui.Nodes.Add("bsl imprimir - Consola")

$treeInstrucciones.ExpandAll()

$leftPanel.Controls.Add($treeInstrucciones)
$mainContainer.Panel1.Controls.Add($leftPanel)

# ================= PANEL DERECHO =================
$rightContainer = New-Object System.Windows.Forms.SplitContainer
$rightContainer.Dock = "Fill"
$rightContainer.Orientation = "Horizontal"
$rightContainer.SplitterDistance = 450
$rightContainer.BackColor = "#1e1e1e"
$rightContainer.Panel1.BackColor = "#1e1e1e"
$rightContainer.Panel2.BackColor = "#1e1e1e"
$mainContainer.Panel2.Controls.Add($rightContainer)

# ================= PANEL SUPERIOR - EDITOR Y PESTAÑAS =================
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"
$tabControl.BackColor = "#1e1e1e"
$tabControl.ForeColor = "White"

$tabNueva = New-Object System.Windows.Forms.TabPage
$tabNueva.Text = "Nueva pestaña"
$tabNueva.BackColor = "#1e1e1e"
$tabNueva.ForeColor = "White"

$editorTexto = New-Object System.Windows.Forms.RichTextBox
$editorTexto.Dock = "Fill"
$editorTexto.BackColor = "#1e1e1e"
$editorTexto.ForeColor = "#d4d4d4"
$editorTexto.Font = New-Object System.Drawing.Font("Consolas", 11)
$editorTexto.BorderStyle = "None"
$editorTexto.AcceptsTab = $true
$editorTexto.Text = @'
bsl frame titulo="Mi Aplicacion" tamano="600,400"

    bsl imprimir>[Iniciando aplicacion...] bsl/imprimir
    
    bsl etiqueta texto="Hola Mundo!" posicion="20,20" s+color="cyan" s+tamano="18" s+negrita="true"
    
    bsl cajaTexto id="nombre" posicion="20,70" tamano="250,35" s+circular="12xp" s+colorfondo="#f0f0f0" s+placeholder="Escribe tu nombre"
    
    bsl boton texto="Click" posicion="20,130" tamano="120,40" s+circular="20xp" s+colorfondo="#2196F3" s+color="white" s+tamano="12" s+negrita="true"

bsl/frame
'@

$editorTexto.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq 'S') {
        $guardarItem.PerformClick()
        $_.SuppressKeyPress = $true
    }
    if ($_.KeyCode -eq 'F5') {
        EjecutarBsL
        $_.SuppressKeyPress = $true
    }
})

$lineNumbers = New-Object System.Windows.Forms.Panel
$lineNumbers.Width = 40
$lineNumbers.Dock = "Left"
$lineNumbers.BackColor = "#252526"

for ($i = 1; $i -le 11; $i++) {
    $lblNum = New-Object System.Windows.Forms.Label
    $lblNum.Text = $i.ToString()
    $lblNum.Location = New-Object System.Drawing.Point(5, ($i-1) * 18 + 3)
    $lblNum.Size = New-Object System.Drawing.Size(30, 18)
    $lblNum.ForeColor = "#858585"
    $lblNum.Font = New-Object System.Drawing.Font("Consolas", 9)
    $lineNumbers.Controls.Add($lblNum)
}

$editorPanel = New-Object System.Windows.Forms.Panel
$editorPanel.Dock = "Fill"
$editorPanel.Controls.Add($editorTexto)
$editorPanel.Controls.Add($lineNumbers)

$tabNueva.Controls.Add($editorPanel)
$tabControl.TabPages.Add($tabNueva)

for ($i = 1; $i -le 6; $i++) {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $i.ToString()
    $tab.BackColor = "#1e1e1e"
    $tabControl.TabPages.Add($tab)
}

$rightContainer.Panel1.Controls.Add($tabControl)

# ================= PANEL INFERIOR - CONSOLA =================
$consoleContainer = New-Object System.Windows.Forms.Panel
$consoleContainer.Dock = "Fill"
$consoleContainer.BackColor = "#1e1e1e"

$consoleHeader = New-Object System.Windows.Forms.Panel
$consoleHeader.Height = 30
$consoleHeader.Dock = "Top"
$consoleHeader.BackColor = "#2d2d2d"

$consoleTitle = New-Object System.Windows.Forms.Label
$consoleTitle.Text = "CONSOLA"
$consoleTitle.Location = New-Object System.Drawing.Point(10, 5)
$consoleTitle.Size = New-Object System.Drawing.Size(100, 20)
$consoleTitle.ForeColor = "#FFA500"
$consoleTitle.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$consoleHeader.Controls.Add($consoleTitle)

$consoleClear = New-Object System.Windows.Forms.Button
$consoleClear.Text = "Limpiar"
$consoleClear.Location = New-Object System.Drawing.Point(($rightContainer.Panel2.Width - 100), 3)
$consoleClear.Size = New-Object System.Drawing.Size(80, 24)
$consoleClear.FlatStyle = "Flat"
$consoleClear.ForeColor = "White"
$consoleClear.BackColor = "#3a3a3a"
$consoleClear.Add_Click({ $consolaTexto.Clear() })
$consoleHeader.Controls.Add($consoleClear)

$consoleContainer.Controls.Add($consoleHeader)

$consolaTexto = New-Object System.Windows.Forms.RichTextBox
$consolaTexto.Dock = "Fill"
$consolaTexto.BackColor = "#1e1e1e"
$consolaTexto.ForeColor = "#00ff00"
$consolaTexto.Font = New-Object System.Drawing.Font("Consolas", 10)
$consolaTexto.ReadOnly = $true
$consolaTexto.Text = @"
> Consola limpia
> Consola activada
> Nuevo archivo creado
>>> help
Comandos disponibles: help, clear, run, stop, version

> BsL v4.0 - Interprete Visual
> Instrucciones disponibles:
>   bsl frame - Crea una ventana
>   bsl imprimir - Muestra texto en consola
>   bsl boton - Boton interactivo
>   bsl etiqueta - Texto estatico
>   bsl cajaTexto - Campo entrada
>   bsl lista - Lista elementos
"@

$consoleContainer.Controls.Add($consolaTexto)
$rightContainer.Panel2.Controls.Add($consoleContainer)

# ================= BARRA DE ESTADO =================
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = "#007acc"

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Listo"
$statusLabel.ForeColor = "White"

$statusArchivo = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusArchivo.Text = "Nuevo archivo.bsl"
$statusArchivo.ForeColor = "White"
$statusArchivo.Spring = $true

$statusLinea = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLinea.Text = "Ln 1, Col 1"
$statusLinea.ForeColor = "White"

$statusStrip.Items.AddRange(@($statusLabel, $statusArchivo, $statusLinea))
$form.Controls.Add($statusStrip)

# ================= FUNCIONES =================
function InsertarBsL($tipo) {
    $codigo = ""
    switch($tipo) {
        "frame" { $codigo = "`nbsl frame titulo=`"Mi Ventana`" tamano=`"400,300`"`n    `nbsl/frame" }
        "imprimir" { $codigo = "bsl imprimir>[Texto aqui] bsl/imprimir" }
        "boton" { $codigo = "bsl boton texto=`"Click`" posicion=`"10,10`" tamano=`"120,40`" s+circular=`"20xp`" s+colorfondo=`"#2196F3`" s+color=`"white`"" }
        "etiqueta" { $codigo = "bsl etiqueta texto=`"Texto`" posicion=`"10,10`" s+color=`"black`" s+tamano=`"12`"" }
        "cajatexto" { $codigo = "bsl cajaTexto id=`"entrada`" posicion=`"10,10`" tamano=`"200,30`" s+circular=`"8xp`" s+placeholder=`"Escribe aqui`"" }
        "lista" { $codigo = "bsl lista titulo=`"Mi Lista`" posicion=`"10,10`" tamano=`"300,200`"" }
    }
    $editorTexto.SelectedText = $codigo
    EscribirConsola "Insertado: $tipo"
}

function EscribirConsola($mensaje) {
    $fecha = Get-Date -Format "HH:mm:ss"
    $consolaTexto.AppendText("`n[$fecha] > $mensaje")
    $consolaTexto.ScrollToCaret()
}

function AplicarEstilosControl($control, $linea) {
    $estilos = [EstiloBsL]::new($linea)
    
    if ($estilos.propiedades.ContainsKey('colorfondo')) {
        $control.BackColor = $estilos.GetColor('colorfondo', $control.BackColor)
    }
    
    if ($estilos.propiedades.ContainsKey('color')) {
        $control.ForeColor = $estilos.GetColor('color', $control.ForeColor)
    }
    
    if ($estilos.propiedades.ContainsKey('tamano') -or 
        $estilos.propiedades.ContainsKey('negrita') -or 
        $estilos.propiedades.ContainsKey('cursiva') -or 
        $estilos.propiedades.ContainsKey('subrayado')) {
        $control.Font = $estilos.GetFont($control.Font)
    }
    
    return $estilos
}

function AplicarEstilosBoton($control, $linea) {
    $estilos = AplicarEstilosControl $control $linea
    
    $control.FlatStyle = "Flat"
    $control.FlatAppearance.BorderSize = 0
    
    if ($estilos.propiedades.ContainsKey('borde')) {
        $grosor = $estilos.GetPadding('borde', 0)
        if ($grosor -gt 0) {
            $control.FlatAppearance.BorderSize = $grosor
            $control.FlatStyle = "Standard"
        }
    }
    
    if ($estilos.propiedades.ContainsKey('padding')) {
        $padding = $estilos.GetPadding('padding', 0)
        $control.Padding = New-Object System.Windows.Forms.Padding($padding)
    }
    
    $radio = $estilos.GetRadioBorde($control)
    if ($radio -gt 0) {
        $control.Tag = $radio
    }
    
    if ($estilos.GetBoolean('sombra', $false)) {
        $control.FlatAppearance.BorderSize = 1
        $control.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(50, 0, 0, 0)
    }
}

function AplicarEstilosCajaTexto($control, $linea) {
    $estilos = AplicarEstilosControl $control $linea
    
    if ($estilos.GetBoolean('password', $false)) {
        $control.PasswordChar = '*'
    }
    
    if ($estilos.propiedades.ContainsKey('placeholder')) {
        $placeholder = $estilos.GetString('placeholder', '')
        $control.Tag = @{placeholder = $placeholder; originalColor = $control.ForeColor}
        $control.Text = $placeholder
        $control.ForeColor = [System.Drawing.Color]::Gray
        
        $control.Add_Enter({
            if ($this.Text -eq $this.Tag.placeholder) {
                $this.Text = ''
                $this.ForeColor = $this.Tag.originalColor
            }
        })
        
        $control.Add_Leave({
            if ([string]::IsNullOrWhiteSpace($this.Text)) {
                $this.Text = $this.Tag.placeholder
                $this.ForeColor = [System.Drawing.Color]::Gray
            }
        })
    }
    
    if ($estilos.propiedades.ContainsKey('alineacion')) {
        $alineacion = $estilos.GetString('alineacion', 'izquierda')
        switch ($alineacion.ToLower()) {
            'derecha' { $control.TextAlign = "Right" }
            'centro'  { $control.TextAlign = "Center" }
            default   { $control.TextAlign = "Left" }
        }
    }
    
    if ($estilos.propiedades.ContainsKey('borde')) {
        $grosor = $estilos.GetPadding('borde', 1)
        $control.BorderStyle = "FixedSingle"
    }
    
    if ($estilos.propiedades.ContainsKey('padding')) {
        $padding = $estilos.GetPadding('padding', 0)
        $control.Margin = New-Object System.Windows.Forms.Padding($padding)
    }
}

function EjecutarBsL {
    if ($script:ejecutando) {
        EscribirConsola "Ya hay un programa en ejecucion"
        return
    }
    
    $script:ejecutando = $true
    $btnEjecutar.Enabled = $false
    $btnDetener.Enabled = $true
    $script:controles = @{}
    
    EscribirConsola "Interpretando codigo BsL..."
    
    try {
        $codigo = $editorTexto.Text
        
        if ($codigo -match 'bsl frame titulo="([^"]*)" tamano="([^"]*)"') {
            $titulo = $matches[1]
            $tamano = $matches[2].Split(',')
            
            EscribirConsola "Creando frame: $titulo"
            
            $nuevaVentana = New-Object System.Windows.Forms.Form
            $nuevaVentana.Text = $titulo
            $nuevaVentana.Size = New-Object System.Drawing.Size([int]$tamano[0], [int]$tamano[1])
            $nuevaVentana.StartPosition = "CenterScreen"
            $nuevaVentana.BackColor = "#f0f0f0"
            $nuevaVentana.Tag = "bsl_frame"
            
            $contenido = $codigo -split 'bsl/frame' | Select-Object -First 1
            $contenido = $contenido -replace '.*bsl frame[^\n]*\n', ''
            $lineas = $contenido -split "`n"
            
            foreach ($linea in $lineas) {
                $linea = $linea.Trim()
                if ([string]::IsNullOrWhiteSpace($linea)) { continue }
                
                if ($linea -match '^bsl boton texto="([^"]*)" posicion="([^"]*)" tamano="([^"]*)"') {
                    $texto = $matches[1]
                    $pos = $matches[2].Split(',')
                    $tam = $matches[3].Split(',')
                    
                    $btn = New-Object System.Windows.Forms.Button
                    $btn.Text = $texto
                    $btn.Location = New-Object System.Drawing.Point([int]$pos[0], [int]$pos[1])
                    $btn.Size = New-Object System.Drawing.Size([int]$tam[0], [int]$tam[1])
                    $btn.BackColor = "#007acc"
                    $btn.ForeColor = "White"
                    $btn.FlatStyle = "Flat"
                    $btn.FlatAppearance.BorderSize = 0
                    $btn.Add_Click({ 
                        EscribirConsola "Boton clickeado: $($this.Text)" 
                        if ($this.Tag -and $this.Tag.id) {
                            EscribirConsola "ID del boton: $($this.Tag.id)"
                        }
                    })
                    
                    if ($linea -match 'id="([^"]*)"') {
                        $id = $matches[1]
                        if (-not $btn.Tag) { $btn.Tag = @{} }
                        $btn.Tag.id = $id
                        $script:controles[$id] = $btn
                        EscribirConsola "  + Boton registrado con ID: $id"
                    }
                    
                    AplicarEstilosBoton $btn $linea
                    $nuevaVentana.Controls.Add($btn)
                    EscribirConsola "  + Boton: $texto"
                }
                
                elseif ($linea -match '^bsl etiqueta texto="([^"]*)" posicion="([^"]*)"') {
                    $texto = $matches[1]
                    $pos = $matches[2].Split(',')
                    
                    $lbl = New-Object System.Windows.Forms.Label
                    $lbl.Text = $texto
                    $lbl.Location = New-Object System.Drawing.Point([int]$pos[0], [int]$pos[1])
                    $lbl.AutoSize = $true
                    
                    if ($linea -match 'id="([^"]*)"') {
                        $id = $matches[1]
                        if (-not $lbl.Tag) { $lbl.Tag = @{} }
                        $lbl.Tag.id = $id
                        $script:controles[$id] = $lbl
                        EscribirConsola "  + Etiqueta registrada con ID: $id"
                    }
                    
                    AplicarEstilosControl $lbl $linea
                    $nuevaVentana.Controls.Add($lbl)
                    EscribirConsola "  + Etiqueta: $texto"
                }
                
                elseif ($linea -match '^bsl cajaTexto id="([^"]*)" posicion="([^"]*)" tamano="([^"]*)"') {
                    $id = $matches[1]
                    $pos = $matches[2].Split(',')
                    $tam = $matches[3].Split(',')
                    
                    $txt = New-Object System.Windows.Forms.TextBox
                    $txt.Name = $id
                    $txt.Location = New-Object System.Drawing.Point([int]$pos[0], [int]$pos[1])
                    $txt.Size = New-Object System.Drawing.Size([int]$tam[0], [int]$tam[1])
                    $txt.BorderStyle = "FixedSingle"
                    
                    $script:controles[$id] = $txt
                    
                    AplicarEstilosCajaTexto $txt $linea
                    $nuevaVentana.Controls.Add($txt)
                    EscribirConsola "  + Caja texto: $id"
                }
                
                elseif ($linea -match '^bsl lista titulo="([^"]*)" posicion="([^"]*)" tamano="([^"]*)"') {
                    $titulo = $matches[1]
                    $pos = $matches[2].Split(',')
                    $tam = $matches[3].Split(',')
                    
                    $listBox = New-Object System.Windows.Forms.ListBox
                    $listBox.Location = New-Object System.Drawing.Point([int]$pos[0], [int]$pos[1])
                    $listBox.Size = New-Object System.Drawing.Size([int]$tam[0], [int]$tam[1])
                    $listBox.BackColor = "White"
                    $listBox.Items.AddRange(@("Elemento 1", "Elemento 2", "Elemento 3"))
                    
                    if ($linea -match 'id="([^"]*)"') {
                        $id = $matches[1]
                        $script:controles[$id] = $listBox
                        EscribirConsola "  + Lista registrada con ID: $id"
                    }
                    
                    $estilos = AplicarEstilosControl $listBox $linea
                    
                    $lblTitulo = New-Object System.Windows.Forms.Label
                    $lblTitulo.Text = $titulo
                    $lblTitulo.Location = New-Object System.Drawing.Point([int]$pos[0], [int]$pos[1] - 20)
                    $lblTitulo.AutoSize = $true
                    $lblTitulo.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
                    
                    $nuevaVentana.Controls.Add($lblTitulo)
                    $nuevaVentana.Controls.Add($listBox)
                    EscribirConsola "  + Lista: $titulo"
                }
            }
            
            $impresiones = [regex]::Matches($codigo, 'bsl imprimir>\[(.*?)\] bsl/imprimir')
            foreach ($i in $impresiones) {
                EscribirConsola "IMPRIMIR: $($i.Groups[1].Value)"
            }
            
            $script:formularioActual = $nuevaVentana
            $nuevaVentana.Show()
            EscribirConsola "Frame creado exitosamente"
            if ($script:controles.Count -gt 0) {
                EscribirConsola "Controles disponibles: $($script:controles.Keys -join ', ')"
            }
        }
        else {
            EscribirConsola "ADVERTENCIA: No se encontro ningun frame en el codigo"
        }
        
    } catch {
        EscribirConsola "ERROR: $_"
        DetenerBsL
    }
}

function DetenerBsL {
    if ($script:formularioActual) {
        $script:formularioActual.Close()
        $script:formularioActual = $null
    }
    
    $script:ejecutando = $false
    $btnEjecutar.Enabled = $true
    $btnDetener.Enabled = $false
    $script:controles = @{}
    EscribirConsola "Programa detenido"
}

$editorTexto.Add_SelectionChanged({
    $linea = $editorTexto.GetLineFromCharIndex($editorTexto.SelectionStart) + 1
    $columna = $editorTexto.SelectionStart - $editorTexto.GetFirstCharIndexOfCurrentLine() + 1
    $statusLinea.Text = "Ln $linea, Col $columna"
})

$treeInstrucciones.Add_NodeMouseDoubleClick({
    $texto = $_.Node.Text
    if ($texto -match "bsl") {
        if ($texto -match "frame") { InsertarBsL "frame" }
        elseif ($texto -match "etiqueta") { InsertarBsL "etiqueta" }
        elseif ($texto -match "boton") { InsertarBsL "boton" }
        elseif ($texto -match "cajaTexto") { InsertarBsL "cajatexto" }
        elseif ($texto -match "lista") { InsertarBsL "lista" }
        elseif ($texto -match "imprimir") { InsertarBsL "imprimir" }
    }
})

$form.Add_Resize({
    if ($minBtn -and $maxBtn -and $closeBtn -and $titleBar) {
        $minBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 90), 5)
        $maxBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 60), 5)
        $closeBtn.Location = New-Object System.Drawing.Point(($titleBar.Width - 30), 5)
    }
    if ($consoleClear -and $rightContainer) {
        $consoleClear.Location = New-Object System.Drawing.Point(($rightContainer.Panel2.Width - 100), 3)
    }
})

$form.MainMenuStrip = $menuStrip
$form.ShowDialog()
