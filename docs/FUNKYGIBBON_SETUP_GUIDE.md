# FunkyGibbon Server Setup Guide

## Overview
FunkyGibbon is the Python-based server component that provides the backend for The Goodies distributed knowledge graph system. This guide walks through setting up and running the server for testing with the Swift client implementation.

## Prerequisites

- Python 3.9 or higher
- pip package manager
- Git
- Terminal/Command Line access

## Installation Steps

### 1. Clone the Repository

```bash
# Clone the main repository
git clone https://github.com/adrianco/the-goodies.git
cd the-goodies
```

### 2. Navigate to FunkyGibbon Directory

```bash
cd funkygibbon
```

### 3. Create Virtual Environment (Recommended)

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate

# On Windows:
venv\Scripts\activate
```

### 4. Install Dependencies

```bash
# Install required packages
pip install -r requirements.txt

# If requirements.txt doesn't exist, install manually:
pip install fastapi uvicorn sqlalchemy pydantic python-jose passlib bcrypt python-multipart
```

### 5. Configure the Server

Create a `.env` file in the funkygibbon directory:

```env
# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
DATABASE_URL=sqlite:///./funkygibbon.db

# Security Configuration  
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS Configuration (for development)
ALLOW_ORIGINS=["*"]
```

### 6. Initialize the Database

```bash
# Run database initialization
python init_db.py

# Or if using alembic:
alembic upgrade head
```

### 7. Start the Server

```bash
# Start with uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Or run the main script
python main.py
```

## Verifying the Server

### 1. Check Server Status

Open a browser and navigate to:
```
http://localhost:8000/health
```

You should see a JSON response:
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

### 2. Access API Documentation

FunkyGibbon provides automatic API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### 3. Test Authentication Endpoint

```bash
# Test authentication with curl
curl -X POST "http://localhost:8000/api/auth" \
  -H "Content-Type: application/json" \
  -d '{"client_id": "test-client", "password": "test-password"}'
```

## Default Test Credentials

For development/testing, the server may include default credentials:

- **Client ID**: `test-client`
- **Password**: `test-password`

⚠️ **Warning**: Change these in production!

## API Endpoints

### Authentication
- `POST /api/auth` - Authenticate and receive token

### Entities
- `GET /api/entities` - List entities
- `POST /api/entities` - Create entity
- `GET /api/entities/{id}` - Get entity by ID
- `PUT /api/entities/{id}` - Update entity
- `DELETE /api/entities/{id}` - Delete entity

### Relationships
- `GET /api/relationships` - List relationships
- `POST /api/relationships` - Create relationship
- `DELETE /api/relationships/{id}` - Delete relationship

### Synchronization
- `POST /api/sync` - Perform synchronization
- `GET /api/sync/status` - Get sync status

## Troubleshooting

### Port Already in Use
If port 8000 is already in use:
```bash
# Use a different port
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

### Database Connection Issues
- Ensure SQLite database file has proper permissions
- Check DATABASE_URL in .env file
- Try deleting funkygibbon.db and reinitializing

### Module Import Errors
```bash
# Ensure you're in the virtual environment
which python  # Should show venv path

# Reinstall dependencies
pip install --upgrade -r requirements.txt
```

### CORS Issues
For local development, ensure CORS is properly configured in .env:
```env
ALLOW_ORIGINS=["http://localhost:*", "http://127.0.0.1:*"]
```

## Running with Docker (Alternative)

If Docker is available:

```dockerfile
# Dockerfile (create in funkygibbon directory)
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:
```bash
docker build -t funkygibbon .
docker run -p 8000:8000 funkygibbon
```

## Testing with Swift Client

Once the server is running, you can test with the Bertha iOS app:

1. Open Bertha in Xcode Simulator
2. Navigate to Connection tab
3. Enter server URL: `http://localhost:8000`
4. Enter test credentials
5. Tap Connect

The app should successfully connect and sync with the server.

## Monitoring

### View Logs
The server outputs detailed logs to the console. Watch for:
- Incoming requests
- Authentication attempts
- Sync operations
- Error messages

### Database Inspection
```bash
# Open SQLite database
sqlite3 funkygibbon.db

# View tables
.tables

# Check entities
SELECT * FROM entities LIMIT 10;

# Exit
.quit
```

## Next Steps

- Configure proper authentication for production
- Set up HTTPS with SSL certificates
- Configure proper CORS origins
- Set up logging to files
- Configure database backups
- Set up monitoring and alerting

## Support

For issues with FunkyGibbon server:
- Check the Python implementation at: https://github.com/adrianco/the-goodies
- Review server logs for error messages
- Ensure all dependencies are installed
- Verify network connectivity