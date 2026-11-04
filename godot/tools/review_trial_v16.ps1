param(
    [switch]$SkipBuild,
    [string]$BlenderExe = 'E:\6e\ide开发版本\blender-5.2.2\blender-5.2.2-windows-x64\blender.exe'
)

$ErrorActionPreference = 'Stop'
$reviewRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godotExe = Join-Path $reviewRoot '.godot-toolchain\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$godotProject = Join-Path $reviewRoot 'godot'
$buildScript = Join-Path $godotProject 'art_source\cangmang_trial_hall_v16\build_trial_hall_v16.py'
$glb = Join-Path $godotProject 'assets\hd2d\world_v16\cangmang_trial_hall_v16.glb'
$importedDir = Join-Path $godotProject '.godot\imported'

foreach ($required in @($godotExe, $BlenderExe, $buildScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing review dependency: $required"
    }
}

Push-Location -LiteralPath $reviewRoot
try {
    if (-not $SkipBuild) {
        & $BlenderExe -b -t 4 --python $buildScript 2>&1 |
            Select-String 'TRIAL_HALL_V16_BUILD_PASS|Error|Traceback'
        if ($LASTEXITCODE -ne 0) { throw 'Blender V16 build failed' }
    }
    if (-not (Test-Path -LiteralPath $glb -PathType Leaf)) {
        throw "No exported V16 GLB: $glb"
    }

    $imported = Get-ChildItem -LiteralPath $importedDir -Filter 'cangmang_trial_hall_v16.glb-*.scn' |
        Select-Object -First 1
    if ($null -eq $imported -or $imported.LastWriteTimeUtc -lt (Get-Item -LiteralPath $glb).LastWriteTimeUtc) {
        & $godotExe --headless --editor --path $godotProject --quit 2>&1 |
            Select-String 'ERROR|Error|cangmang_trial_hall_v16.glb|DONE'
        if ($LASTEXITCODE -ne 0) { throw 'Godot V16 import failed' }
    }
    $imported = Get-ChildItem -LiteralPath $importedDir -Filter 'cangmang_trial_hall_v16.glb-*.scn' |
        Select-Object -First 1
    if ($null -eq $imported -or $imported.LastWriteTimeUtc -lt (Get-Item -LiteralPath $glb).LastWriteTimeUtc) {
        throw 'Godot imported scene is older than the exported V16 GLB'
    }

    foreach ($view in @(
        @('--candidate=default'),
        @('--candidate=default', '--yaw=20'),
        @('--candidate=default', '--pose-study=runtime-contact'),
        @('--candidate=trial_v16', '--pose-study=idle-frame-1'),
        @('--candidate=trial_v16', '--yaw=20', '--pose-study=idle-frame-1'),
        @('--candidate=trial_v16', '--pose-study=runtime-contact')
    )) {
        & $godotExe --path $godotProject --rendering-method forward_plus `
            -s res://tools/capture_first_fight_render_backend.gd -- $view 2>&1 |
            Select-String 'ERROR|Error|RUNTIME_CONTACT_ALIGNMENT|FIRST_FIGHT_BACKEND_CAPTURE'
        if ($LASTEXITCODE -ne 0) { throw "Godot V16 capture failed: $view" }
    }

    & $godotExe --headless --path $godotProject -s res://tests/play_full_battle_ui.gd 2>&1 |
        Select-String 'ERROR|Error|M0_FULL_BATTLE_UI_PASS'
    if ($LASTEXITCODE -ne 0) { throw 'Default full battle UI replay failed' }
    & $godotExe --headless --path $godotProject -s res://tests/hd2d_stage_contract.gd 2>&1 |
        Select-String 'ERROR|Error|HD2D_STAGE_CONTRACT_PASS'
    if ($LASTEXITCODE -ne 0) { throw 'Default four-phase actor stage contract failed' }
    & $godotExe --headless --path $godotProject -s res://tests/play_full_battle_ui.gd `
        -- --trial-v16-candidate 2>&1 |
        Select-String 'ERROR|Error|M0_FULL_BATTLE_UI_PASS'
    if ($LASTEXITCODE -ne 0) { throw 'V16 candidate full battle UI replay failed' }
    & python godot/tools/build_battlefield_art_catalog.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Battlefield catalog check failed' }

    Write-Output "V16_REVIEW_PASS GLB=$glb"
} finally {
    Pop-Location
}
