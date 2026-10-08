<#
.SYNOPSIS
    Pausa o reanuda una capacidad de Microsoft Fabric desde Azure Automation.

.DESCRIPTION
    Pensado para un runbook de PowerShell (runtime 7.2 o superior) en una cuenta de Azure Automation
    con identidad administrada asignada por el sistema. La identidad necesita un rol sobre la capacidad
    con las acciones read, write, suspend/action y resume/action (ver 05-rol-personalizado.json).

    Antes de actuar consulta el estado: si la capacidad ya está como se pidió, no hace nada.
    Después espera a que la capacidad llegue al estado final y falla con un error claro si no lo logra.

.PARAMETER Accion
    Pausar o Reanudar.

.PARAMETER SubscriptionId
    ID de la suscripción donde está la capacidad.

.PARAMETER ResourceGroupName
    Grupo de recursos de la capacidad.

.PARAMETER CapacityName
    Nombre de la capacidad de Fabric (el recurso de Azure, en minúsculas).

.PARAMETER EsperarMinutos
    Cuánto esperar a que la capacidad cambie de estado. Por defecto, 10.

.EXAMPLE
    Programación "Pausar 19:00":   Accion = Pausar
    Programación "Reanudar 8:00":  Accion = Reanudar
    (los otros tres parámetros se completan con los datos de tu capacidad)

.NOTES
    Maxi Accotto · TriggerDB · https://www.triggerdb.com
#>
param(
    [Parameter(Mandatory)] [ValidateSet('Pausar', 'Reanudar')] [string] $Accion,
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroupName,
    [Parameter(Mandatory)] [string] $CapacityName,
    [int] $EsperarMinutos = 10
)

$ErrorActionPreference = 'Stop'

# Conexión con la identidad administrada de la cuenta de Automation (sin usuarios ni contraseñas)
Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -Identity | Out-Null
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

$apiVersion = '2023-11-01'
$basePath   = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName"

if ($Accion -eq 'Pausar') { $operacion = 'suspend'; $estadosFinales = @('Paused', 'Suspended') }
else                      { $operacion = 'resume';  $estadosFinales = @('Active') }

function Get-EstadoCapacidad {
    # Ojo: ${basePath} va entre llaves. Sin llaves, PowerShell toma "?api" como parte del nombre de la variable
    # y la URL queda mal armada. Invoke-AzRestMethod no falla ante un HTTP 4xx, por eso se valida StatusCode.
    $r = Invoke-AzRestMethod -Method GET -Path "${basePath}?api-version=$apiVersion"
    if ($r.StatusCode -ne 200) { throw "No se pudo leer la capacidad '$CapacityName' (HTTP $($r.StatusCode)): $($r.Content)" }
    return ($r.Content | ConvertFrom-Json).properties.state
}

$estado = Get-EstadoCapacidad
Write-Output "Capacidad: $CapacityName | Estado actual: $estado | Acción pedida: $Accion"

if ($estado -in $estadosFinales) {
    Write-Output "No hace falta hacer nada: la capacidad ya está en '$estado'."
    return
}

Write-Output "Enviando '$operacion'..."
$r = Invoke-AzRestMethod -Method POST -Path "$basePath/${operacion}?api-version=$apiVersion"
if ($r.StatusCode -notin 200, 202) {
    throw "La operación '$operacion' falló (HTTP $($r.StatusCode)): $($r.Content)"
}

# Esperar a que la capacidad llegue al estado final
$limite = (Get-Date).AddMinutes($EsperarMinutos)
do {
    Start-Sleep -Seconds 20
    $estado = Get-EstadoCapacidad
    Write-Output "Estado: $estado"
} while ($estado -notin $estadosFinales -and (Get-Date) -lt $limite)

if ($estado -notin $estadosFinales) {
    throw "La capacidad no llegó a '$($estadosFinales -join ' / ')' en $EsperarMinutos minutos (estado actual: $estado)."
}
Write-Output "Listo: la capacidad '$CapacityName' quedó en '$estado'."
