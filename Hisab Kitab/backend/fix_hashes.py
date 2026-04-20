import sqlite3, bcrypt

conn = sqlite3.connect('budget_india.db')
demo_hash = bcrypt.hashpw(b'admin123', bcrypt.gensalt()).decode('utf-8')
for u in ['admin', 'health_dept', 'education_dept', 'public_user']:
    conn.execute('UPDATE users SET hashed_password=? WHERE username=?', (demo_hash, u))
    print(f'Updated {u}')
conn.commit()

row = conn.execute('SELECT username, hashed_password FROM users WHERE username=?', ('admin',)).fetchone()
ok = bcrypt.checkpw(b'admin123', row[1].encode())
print(f'Verify admin login: {ok}')
conn.close()
