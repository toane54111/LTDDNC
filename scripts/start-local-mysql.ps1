$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$mysqlExecutable = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe'
$mysqlData = Join-Path $projectRoot 'runtime\mysql'
$mysqlLog = Join-Path $projectRoot 'runtime\mysql.log'
if (-not (Test-Path -LiteralPath (Join-Path $mysqlData 'auto.cnf'))) {
    throw 'Chưa có dữ liệu MySQL riêng. Xem README để cấu hình bằng Docker hoặc MySQL hiện có.'
}
if (Get-NetTCPConnection -State Listen -LocalPort 3307 -ErrorAction SilentlyContinue) {
    Write-Host 'Cổng 3307 đang có dịch vụ. Không khởi động thêm MySQL.'
    exit 0
}
Start-Process -FilePath $mysqlExecutable -ArgumentList @(
    '--no-defaults',
    '--basedir="C:\Program Files\MySQL\MySQL Server 8.0"',
    "--datadir=`"$mysqlData`"",
    '--port=3307',
    '--bind-address=127.0.0.1',
    '--mysqlx=OFF',
    "--log-error=`"$mysqlLog`""
) -WindowStyle Hidden
Write-Host 'Đã khởi động MySQL riêng trên cổng 3307. Log nằm trong runtime/mysql.log.'
