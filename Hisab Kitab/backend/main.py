# main.py
from fastapi import FastAPI, Query, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from datetime import datetime, timedelta
from typing import Optional, List
import asyncio
from jose import JWTError, jwt
import bcrypt
from pydantic import BaseModel
import sqlite3
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
import json
import os
import secrets

app = FastAPI(title="Indian Budget Intelligence API")

# ============ AUTHENTICATION CONFIGURATION ============
# 🔑 GENERATE YOUR KEY USING: python -c "import secrets; print(secrets.token_urlsafe(32))"
SECRET_KEY = "vQOONJ_H8PA7IRaUJxNS1sdwLdx8vvJIqHu3u_auC_o"  
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Pydantic models for auth
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: str
    department: Optional[str] = None
    disabled: Optional[bool] = None

class UserInDB(User):
    hashed_password: str

# Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database path
DB_PATH = 'budget_india.db'

# ============ DATABASE FUNCTIONS FOR AUTH ============
def init_auth_db():
    """Initialize users table in SQLite"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE,
            full_name TEXT,
            hashed_password TEXT NOT NULL,
            role TEXT NOT NULL,
            department TEXT,
            disabled BOOLEAN DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Insert demo users (password: admin123 for all)
    demo_hash = bcrypt.hashpw(b"admin123", bcrypt.gensalt()).decode("utf-8")
    for uname, email, fname, role, dept in [
        ('admin', 'admin@gov.in', 'Admin User', 'admin', None),
        ('health_dept', 'health@gov.in', 'Health Officer', 'department', 'Health'),
        ('education_dept', 'education@gov.in', 'Education Officer', 'department', 'Education'),
        ('public_user', 'public@citizen.in', 'Public User', 'public', None),
    ]:
        cursor.execute('''
            INSERT INTO users (username, email, full_name, hashed_password, role, department)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(username) DO UPDATE SET hashed_password=excluded.hashed_password
        ''', (uname, email, fname, demo_hash, role, dept))
    
    conn.commit()
    conn.close()
    print("✅ Auth database initialized with demo users")

# Password utilities
def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))

def get_password_hash(password):
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def get_user(username: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT username, email, full_name, hashed_password, role, department, disabled FROM users WHERE username = ?", 
        (username,)
    )
    user = cursor.fetchone()
    conn.close()
    
    if user:
        return UserInDB(
            username=user[0],
            email=user[1],
            full_name=user[2],
            hashed_password=user[3],
            role=user[4],
            department=user[5],
            disabled=bool(user[6])
        )
    return None

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user:
        return False
    if not verify_password(password, user.hashed_password):
        return False
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username, role=payload.get("role"))
    except JWTError:
        raise credentials_exception
    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    if current_user.disabled:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Role-based access decorators
def require_role(required_role: str):
    async def role_checker(current_user: User = Depends(get_current_active_user)):
        if current_user.role != required_role and current_user.role != 'admin':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role {required_role} required"
            )
        return current_user
    return role_checker

def require_department_access(allowed_depts: list = None):
    async def dept_checker(current_user: User = Depends(get_current_active_user)):
        if current_user.role == 'admin':
            return current_user
        if current_user.role == 'department':
            if allowed_depts and current_user.department not in allowed_depts:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access to this department data not allowed"
                )
            return current_user
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Department access required"
        )
    return dept_checker

# ============ AUTHENTICATION ENDPOINTS ============

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "dept": user.department}, 
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    return current_user

@app.post("/register")
async def register_user(username: str, password: str, email: str, full_name: str, role: str = "public"):
    # Check if user exists
    existing = get_user(username)
    if existing:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Hash password and create user
    hashed = get_password_hash(password)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (username, email, full_name, hashed_password, role) VALUES (?, ?, ?, ?, ?)",
            (username, email, full_name, hashed, role)
        )
        conn.commit()
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Email already registered")
    finally:
        conn.close()
    
    return {"message": "User created successfully", "username": username}

# ============ YOUR EXISTING ENDPOINTS (WITH AUTH ADDED) ============

# Helper function to convert dataframe to JSON serializable
def df_to_json(df):
    return json.loads(df.to_json(orient='records', date_format='iso'))

@app.get("/")
def root():
    return {
        "name": "Indian Budget Intelligence Platform",
        "version": "1.0",
        "status": "running",
        "database": os.path.exists(DB_PATH),
        "auth_required": "Use /token to get access token",
        "endpoints": [
            "/api/summary",
            "/api/states",
            "/api/districts/{state}",
            "/api/ministries",
            "/api/departments",
            "/api/anomalies/{department}",
            "/api/leakage",
            "/api/reallocate",
            "/api/high-risk"
        ]
    }

# 1. GET OVERALL SUMMARY (Public - no auth required)
@app.get("/api/summary")
async def get_summary():
    """Get overall budget summary - Public access"""
    conn = sqlite3.connect(DB_PATH)
    
    query = """
    SELECT 
        COUNT(DISTINCT State) as total_states,
        COUNT(DISTINCT District) as total_districts,
        COUNT(DISTINCT Ministry) as total_ministries,
        COUNT(DISTINCT Department) as total_departments,
        SUM(Allocated_Budget_Cr) as total_allocated_cr,
        SUM(Actual_Spending_Cr) as total_spent_cr,
        AVG(Utilization_Percentage) as avg_utilization,
        SUM(CASE WHEN Utilization_Percentage < 50 THEN 1 ELSE 0 END) as critical_underspend,
        SUM(CASE WHEN Utilization_Percentage > 150 THEN 1 ELSE 0 END) as critical_overspend
    FROM budget
    """
    
    df = pd.read_sql(query, conn)
    conn.close()
    
    # Calculate waste
    if not df.empty:
        df['total_waste_cr'] = df['total_allocated_cr'] - df['total_spent_cr']
    
    return JSONResponse(content=df_to_json(df)[0] if not df.empty else {})

# 2. GET ALL STATES (Public)
@app.get("/api/states")
async def get_states():
    """Get list of all states - Public access"""
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql("SELECT DISTINCT State FROM budget ORDER BY State", conn)
    conn.close()
    return {"states": df['State'].tolist()}

# 3. GET DISTRICTS BY STATE (Public)
@app.get("/api/districts/{state}")
async def get_districts(state: str):
    """Get districts in a state - Public access"""
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql("SELECT DISTINCT District FROM budget WHERE State = ? ORDER BY District", 
                     conn, params=[state])
    conn.close()
    return {"state": state, "districts": df['District'].tolist()}

# 4. GET MINISTRIES (Public)
@app.get("/api/ministries")
async def get_ministries():
    """Get list of ministries - Public access"""
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql("SELECT DISTINCT Ministry FROM budget ORDER BY Ministry", conn)
    conn.close()
    return {"ministries": df['Ministry'].tolist()}

# 5. GET DEPARTMENTS (Public)
@app.get("/api/departments")
async def get_departments():
    """Get list of departments - Public access"""
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql("SELECT DISTINCT Department FROM budget ORDER BY Department", conn)
    conn.close()
    return {"departments": df['Department'].tolist()}

# 6. DEPARTMENT WISE SUMMARY (Requires authentication)
@app.get("/api/department/{dept}")
async def department_summary(
    dept: str, 
    current_user: User = Depends(get_current_active_user)
):
    """Get summary for specific department - Auth required"""
    conn = sqlite3.connect(DB_PATH)
    
    query = """
    SELECT 
        State,
        District,
        SUM(Allocated_Budget_Cr) as total_allocated,
        SUM(Actual_Spending_Cr) as total_spent,
        AVG(Utilization_Percentage) as avg_utilization,
        SUM(Remaining_Budget_Cr) as total_remaining,
        AVG(Delay_Days) as avg_delay,
        COUNT(CASE WHEN Anomaly_Tag != 'Normal' THEN 1 END) as anomaly_count
    FROM budget
    WHERE Department = ?
    GROUP BY State, District
    ORDER BY avg_utilization ASC
    """
    
    df = pd.read_sql(query, conn, params=[dept])
    conn.close()
    
    return JSONResponse(content=df_to_json(df))

# 7. ANOMALY DETECTION (ML-BASED) - Department users can access their own department
@app.get("/api/anomalies/{department}")
async def detect_anomalies(
    department: str, 
    current_user: User = Depends(require_department_access())
):
    """Detect anomalies using ML - Department access only"""
    # Verify access to this specific department
    if current_user.role != "admin" and current_user.department != department:
        raise HTTPException(
            status_code=403, 
            detail="You do not have access to this department's data"
        )
        
    conn = sqlite3.connect(DB_PATH)
    
    query = "SELECT * FROM budget WHERE Department = ?"
    df = pd.read_sql(query, conn, params=[department])
    conn.close()
    
    if len(df) < 10:
        return {
            "department": department,
            "total_records": len(df),
            "ml_anomalies_found": 0,
            "tagged_anomalies": 0,
            "anomalies": [],
            "message": "Not enough data for ML detection"
        }
    
    # Use Isolation Forest for anomaly detection
    model = IsolationForest(contamination=0.1, random_state=42)
    
    # Features for anomaly detection
    features = df[['Utilization_Percentage', 'Delay_Days']].fillna(0)
    df['ml_anomaly'] = model.fit_predict(features)
    
    # Get ML-detected anomalies (-1 means anomaly)
    ml_anomalies = df[df['ml_anomaly'] == -1].to_dict('records')
    
    # Also include records with Anomaly_Tag from original data
    df['Anomaly_Tag'] = df['Anomaly_Tag'].fillna('Normal')
    tagged_anomalies = df[df['Anomaly_Tag'].str.upper() != 'NORMAL'].to_dict('records')
    
    # Combine (limit to 20 for response size)
    all_anomalies = (ml_anomalies + tagged_anomalies)[:20]
    
    # Convert any non-serializable types
    for a in all_anomalies:
        for key, value in a.items():
            if isinstance(value, (np.integer, np.floating)):
                a[key] = float(value)
            elif isinstance(value, np.bool_):
                a[key] = bool(value)
    
    return {
        "department": department,
        "total_records": len(df),
        "ml_anomalies_found": len(ml_anomalies),
        "tagged_anomalies": len(tagged_anomalies),
        "anomalies": all_anomalies
    }

# 8. LEAKAGE DETECTION (Admin only)
@app.get("/api/leakage")
async def detect_leakage(
    min_utilization: float = 50,
    current_user: User = Depends(require_role('admin'))
):
    """Find potential leakages - Admin only"""
    conn = sqlite3.connect(DB_PATH)
    
    query = """
    SELECT 
        State,
        District,
        Ministry,
        Department,
        Scheme_Name,
        SUM(Allocated_Budget_Cr) as total_allocated,
        SUM(Actual_Spending_Cr) as total_spent,
        AVG(Utilization_Percentage) as avg_utilization,
        SUM(Remaining_Budget_Cr) as unspent_amount,
        AVG(Delay_Days) as avg_delay,
        COUNT(*) as record_count
    FROM budget
    GROUP BY State, District, Ministry, Department, Scheme_Name
    HAVING avg_utilization < ?
    ORDER BY unspent_amount DESC
    LIMIT 50
    """
    
    df = pd.read_sql(query, conn, params=[min_utilization])
    conn.close()
    
    # Convert numpy types
    result = df.to_dict('records')
    for r in result:
        for key, value in r.items():
            if isinstance(value, (np.integer, np.floating)):
                r[key] = float(value)
    
    return JSONResponse(content=result)

# 9. REALLOCATION SUGGESTIONS (Admin only)
@app.get("/api/reallocate")
async def suggest_reallocation(
    current_user: User = Depends(require_role('admin'))
):
    """Suggest reallocating funds - Admin only"""
    conn = sqlite3.connect(DB_PATH)
    
    # Find underutilized (Utilization < 40%)
    under = pd.read_sql("""
        SELECT 
            State,
            District,
            Department,
            Scheme_Name,
            SUM(Allocated_Budget_Cr) as allocated,
            AVG(Utilization_Percentage) as utilization,
            SUM(Remaining_Budget_Cr) as surplus
        FROM budget
        GROUP BY State, District, Department, Scheme_Name
        HAVING utilization < 40
        ORDER BY surplus DESC
        LIMIT 10
    """, conn)
    
    # Find overutilized (Utilization > 130%)
    over = pd.read_sql("""
        SELECT 
            State,
            District,
            Department,
            Scheme_Name,
            SUM(Allocated_Budget_Cr) as allocated,
            AVG(Utilization_Percentage) as utilization,
            (SUM(Actual_Spending_Cr) - SUM(Allocated_Budget_Cr)) as deficit
        FROM budget
        GROUP BY State, District, Department, Scheme_Name
        HAVING utilization > 130
        ORDER BY deficit DESC
        LIMIT 10
    """, conn)
    
    conn.close()
    
    suggestions = []
    for i in range(min(len(under), len(over))):
        u = under.iloc[i]
        o = over.iloc[i]
        
        # Only suggest if same department
        if u['Department'] == o['Department']:
            realloc_amount = min(u['surplus'] * 0.7, o['deficit'] * 0.5 if o['deficit'] > 0 else u['surplus'] * 0.3)
            suggestions.append({
                "from_location": f"{u['District']}, {u['State']}",
                "to_location": f"{o['District']}, {o['State']}",
                "department": u['Department'],
                "scheme": u['Scheme_Name'],
                "current_utilization_from": f"{u['utilization']:.1f}%",
                "current_utilization_to": f"{o['utilization']:.1f}%",
                "suggested_amount_cr": round(float(realloc_amount), 2),
                "reason": f"Reallocate from underutilized ({u['utilization']:.1f}%) to overburdened ({o['utilization']:.1f}%) scheme"
            })
    
    return {"suggestions": suggestions}

# 10. HIGH-RISK PROJECTS (Admin only)
@app.get("/api/high-risk")
async def high_risk_projects(
    threshold: float = 30,
    current_user: User = Depends(require_role('admin'))
):
    """Find high-risk projects - Admin only"""
    conn = sqlite3.connect(DB_PATH)
    
    query = """
    SELECT 
        State,
        District,
        Ministry,
        Department,
        Scheme_Name,
        Project_ID,
        Allocated_Budget_Cr,
        Utilization_Percentage,
        Delay_Days,
        Anomaly_Tag
    FROM budget
    WHERE Utilization_Percentage < ? OR Delay_Days > 90
    ORDER BY Utilization_Percentage ASC, Delay_Days DESC
    LIMIT 50
    """
    
    df = pd.read_sql(query, conn, params=[threshold])
    conn.close()
    
    # Convert numpy types
    result = df.to_dict('records')
    for r in result:
        for key, value in r.items():
            if isinstance(value, (np.integer, np.floating)):
                r[key] = float(value)
            elif pd.isna(value):
                r[key] = None
    
    return JSONResponse(content=result)

# 11. STATE-WISE SUMMARY (Public - no auth)
@app.get("/api/state/{state}")
async def state_summary(state: str):
    """Get summary for a specific state - Public access"""
    conn = sqlite3.connect(DB_PATH)
    
    query = """
    SELECT 
        District,
        Department,
        SUM(Allocated_Budget_Cr) as allocated,
        SUM(Actual_Spending_Cr) as spent,
        AVG(Utilization_Percentage) as utilization,
        AVG(Delay_Days) as avg_delay
    FROM budget
    WHERE State = ?
    GROUP BY District, Department
    ORDER BY utilization ASC
    """
    
    df = pd.read_sql(query, conn, params=[state])
    conn.close()
    
    # Convert numpy types
    result = df.to_dict('records')
    for r in result:
        for key, value in r.items():
            if isinstance(value, (np.integer, np.floating)):
                r[key] = float(value)
    
    return JSONResponse(content=result)

# 12. HEALTH CHECK (Public)
@app.get("/api/health")
async def health_check():
    """Check if API and database are working"""
    try:
        conn = sqlite3.connect(DB_PATH)
        count = conn.execute("SELECT COUNT(*) FROM budget").fetchone()[0]
        conn.close()
        return {
            "status": "healthy",
            "database": "connected",
            "records": count,
            "database_file": os.path.exists(DB_PATH)
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }

# ============ WEBSOCKET ALERT SYSTEM ============
class AlertManager:
    def __init__(self):
        self.connections: List[WebSocket] = []
        self._running = False

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.connections.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self.connections:
            self.connections.remove(ws)

    async def broadcast(self, message: dict):
        dead = []
        for ws in self.connections:
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

    async def generate_alerts(self):
        """Background task that checks for anomalies and broadcasts alerts."""
        if self._running:
            return
        self._running = True
        try:
            while True:
                await asyncio.sleep(30)  # check every 30 seconds
                if not self.connections:
                    continue
                try:
                    conn = sqlite3.connect(DB_PATH)
                    # Find critical underspend (< 30% utilization)
                    df = pd.read_sql_query(
                        "SELECT State, District, Department, allocated, spent FROM budget WHERE utilization < 30 ORDER BY RANDOM() LIMIT 3",
                        conn
                    )
                    conn.close()
                    for _, row in df.iterrows():
                        alert = {
                            "type": "critical_underspend",
                            "severity": "high",
                            "title": f"Critical Underspend: {row['District']}",
                            "message": f"{row['Department']} in {row['District']}, {row['State']} — allocated ₹{row['allocated']:.1f}Cr but spent only ₹{row['spent']:.1f}Cr",
                            "timestamp": datetime.utcnow().isoformat(),
                        }
                        await self.broadcast(alert)
                except Exception:
                    pass
        finally:
            self._running = False

alert_manager = AlertManager()

@app.websocket("/ws/alerts")
async def websocket_alerts(ws: WebSocket):
    await alert_manager.connect(ws)
    # start background alert generator if not already running
    asyncio.ensure_future(alert_manager.generate_alerts())
    try:
        while True:
            # keep connection alive; respond to pings
            data = await ws.receive_text()
            if data == "ping":
                await ws.send_json({"type": "pong"})
    except WebSocketDisconnect:
        alert_manager.disconnect(ws)

# Initialize auth DB on startup
@app.on_event("startup")
async def startup_event():
    init_auth_db()

if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting Indian Budget Intelligence API...")
    print("📊 Database:", DB_PATH)
    print("📝 API docs: http://localhost:8000/docs")
    print("🔑 Auth endpoint: http://localhost:8000/token")
    print("📍 Working directory:", os.getcwd())
    print("\n👤 Demo Users (password: admin123 for all):")
    print("   - admin (full access)")
    print("   - health_dept (health department only)")
    print("   - education_dept (education department only)")
    print("   - public_user (read-only access)\n")
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)