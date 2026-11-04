param(
    [switch]$SkipBuild,
    [string]$BlenderExe = 'E:\6e\ide开发版本\blender-5.2.2\blender-5.2.2-windows-x64\blender.exe'
)

$ErrorActionPreference = 'Stop'
$reviewRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godotExe = Join-Path $reviewRoot '.godot-toolchain\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$godotProject = Join-Path $reviewRoot 'godot'
$buildScript = Join-Path $godotProject 'art_source\qingyun_tutorial_hall_v17\build_tutorial_hall_v17.py'
$glb = Join-Path $godotProject 'assets\hd2d\world_v17\qingyun_tutorial_hall_v17.glb'
$importedDir = Join-Path $godotProject '.godot\imported'

foreach ($required in @($godotExe, $buildScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing review dependency: $required"
    }
}
if (-not $SkipBuild -and -not (Test-Path -LiteralPath $BlenderExe -PathType Leaf)) {
    throw "Missing Blender executable: $BlenderExe"
}

Push-Location -LiteralPath $reviewRoot
try {
    if (-not $SkipBuild) {
        & $BlenderExe -b -t 4 --python $buildScript 2>&1 |
            Select-String 'QINGYUN_TUTORIAL_HALL_V17_BUILD_PASS|Error|Traceback'
        if ($LASTEXITCODE -ne 0) { throw 'Blender V17 build failed' }
    }
    if (-not (Test-Path -LiteralPath $glb -PathType Leaf)) {
        throw "No exported V17 GLB: $glb"
    }

    $imported = Get-ChildItem -LiteralPath $importedDir -Filter 'qingyun_tutorial_hall_v17.glb-*.scn' |
        Select-Object -First 1
    if ($null -eq $imported -or $imported.LastWriteTimeUtc -lt (Get-Item -LiteralPath $glb).LastWriteTimeUtc) {
        & $godotExe --headless --editor --path $godotProject --quit 2>&1 |
            Select-String 'ERROR|Error|qingyun_tutorial_hall_v17.glb|DONE'
        if ($LASTEXITCODE -ne 0) { throw 'Godot V17 import failed' }
    }
    $imported = Get-ChildItem -LiteralPath $importedDir -Filter 'qingyun_tutorial_hall_v17.glb-*.scn' |
        Select-Object -First 1
    if ($null -eq $imported -or $imported.LastWriteTimeUtc -lt (Get-Item -LiteralPath $glb).LastWriteTimeUtc) {
        throw 'Godot imported scene is older than the exported V17 GLB'
    }

    foreach ($view in @(
        @('--candidate=default'),
        @('--candidate=default', '--yaw=20'),
        @('--candidate=default', '--yaw=-20'),
        @('--candidate=default', '--pose-study=runtime-contact')
    )) {
        & $godotExe --path $godotProject --rendering-method forward_plus `
            --resolution 1280x800 --windowed `
            -s res://tools/capture_first_fight_render_backend.gd -- $view 2>&1 |
            Select-String 'ERROR|Error|RUNTIME_CONTACT_ALIGNMENT|FIRST_FIGHT_BACKEND_CAPTURE'
        if ($LASTEXITCODE -ne 0) { throw "Godot V17 capture failed: $view" }
    }

    foreach ($test in @(
        'res://tests/battlefield_art_registry_contract.gd',
        'res://tests/hd2d_stage_contract.gd',
        'res://tests/play_full_battle_ui.gd',
        'res://tests/noncombat_opening_ui.gd',
        'res://tools/validate_card_pointer_hover.gd',
        'res://tools/validate_s1_contact_alignment.gd'
    )) {
        & $godotExe --headless --path $godotProject -s $test 2>&1 |
            Select-String 'PASS|ERROR|Error'
        if ($LASTEXITCODE -ne 0) { throw "Godot V17 review failed: $test" }
    }
    & python godot/tools/build_battlefield_art_catalog.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Battlefield catalog check failed' }

    Write-Output "TUTORIAL_V17_REVIEW_PASS GLB=$glb"
} finally {
    Pop-Location
}
