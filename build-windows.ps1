<#
.SYNOPSIS
  gym-management Windows .exe 빌드 스크립트
.DESCRIPTION
  Flutter Windows 빌드는 Linux Docker에서 불가능하므로 Windows 호스트에서 직접 실행합니다.
  결과물: build\windows\x64\runner\Release\
.EXAMPLE
  .\build-windows.ps1
  .\build-windows.ps1 -Clean   # 클린 빌드
#>

param([switch]$Clean)

$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot

Write-Host "=== gym-management Windows 빌드 시작 ===" -ForegroundColor Cyan

Set-Location $ProjectDir

if ($Clean) {
    Write-Host "클린 빌드 실행 중..." -ForegroundColor Yellow
    flutter clean
}

Write-Host "의존성 설치 중..." -ForegroundColor Yellow
flutter pub get

Write-Host "Windows 앱 빌드 중..." -ForegroundColor Yellow
flutter build windows --release

$OutputDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"
if (Test-Path $OutputDir) {
    Write-Host ""
    Write-Host "=== 빌드 완료 ===" -ForegroundColor Green
    Write-Host "결과물 위치: $OutputDir" -ForegroundColor Green
    Write-Host "배포 시 해당 폴더 전체를 복사하세요." -ForegroundColor Gray
} else {
    Write-Host "빌드 실패: 결과물을 찾을 수 없습니다." -ForegroundColor Red
    exit 1
}
