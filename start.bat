@echo off
echo ================================
echo Payroll System - Quick Start
echo ================================
echo.

echo Checking Docker...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not installed or not running!
    echo Please install Docker Desktop and try again.
    pause
    exit /b 1
)

echo Docker is running!
echo.

echo Creating .env file if it doesn't exist...
if not exist .env (
    copy .env.example .env
    echo .env file created!
) else (
    echo .env file already exists
)
echo.

echo Starting services with Docker Compose...
docker-compose up -d

echo.
echo ================================
echo Services starting...
echo ================================
echo.
echo Please wait 30 seconds for services to initialize...
echo.
timeout /t 30 /nobreak >nul

echo ================================
echo Checking services status...
echo ================================
docker-compose ps

echo.
echo ================================
echo Services are ready!
echo ================================
echo.
echo Backend API:  http://localhost:8000
echo API Docs:     http://localhost:8000/docs
echo Frontend:     http://localhost:3000
echo.
echo Press any key to open the frontend in browser...
pause >nul

start http://localhost:3000

echo.
echo To stop the services, run: docker-compose down
echo To view logs, run: docker-compose logs -f
echo.
pause
