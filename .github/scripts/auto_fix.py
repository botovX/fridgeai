import os, json, re, subprocess, requests
from pathlib import Path

log_file = Path("build-output.log")
if not log_file.exists():
    print("❌ Fichier build-output.log introuvable")
    exit(1)

logs = log_file.read_text()
print(f"📖 Logs lus : {len(logs)} caractères")

error_lines = [line for line in logs.split("\n") if "error" in line.lower() or "failed" in line.lower()]
error_summary = "\n".join(error_lines[-20:])

api_key = os.environ.get('DEEPSEEK_API_KEY', '')
print(f"🔑 Clé API présente : {'OUI' if api_key else 'NON'}")

prompt = f"""Analyse ces erreurs de build Flutter et retourne UNIQUEMENT ce JSON:
{{"file":"chemin/du/fichier","description":"description","fix":"code corrigé complet"}}

Erreurs:
{error_summary[:5000]}
"""

print("🚀 Appel Gemini...")
try:
    response = requests.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}",
        headers={"Content-Type": "application/json"},
        json={
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.1, "maxOutputTokens": 2000}
        },
        timeout=60
    )
    
    print(f"📡 Statut HTTP : {response.status_code}")
    
    if response.status_code != 200:
        print(f"❌ Erreur API : {response.text}")
        exit(1)
    
    result = response.json()
    content = result["candidates"][0]["content"]["parts"][0]["text"]
    print(f"💬 Réponse : {content[:500]}")
    
    json_match = re.search(r'\{.*\}', content, re.DOTALL)
    if json_match:
        data = json.loads(json_match.group())
        file_path = Path(data.get("file", ""))
        
        if file_path.exists():
            print(f"🔧 Correction de {file_path}")
            file_path.write_text(data.get("fix", ""))
            
            subprocess.run(["git", "config", "user.name", "AI Bot"], check=False)
            subprocess.run(["git", "config", "user.email", "bot@ai.com"], check=False)
            subprocess.run(["git", "checkout", "-b", "ai-fix"], check=False)
            subprocess.run(["git", "add", "."], check=False)
            subprocess.run(["git", "commit", "-m", f"Fix: {data.get('description','')}"], check=False)
            subprocess.run(["git", "push", "origin", "ai-fix"], check=False)
            subprocess.run(["gh", "pr", "create", "--title", "🤖 AI Fix", "--body", data.get('description',''), "--base", "main"], check=False)
            print("✅ PR créée !")
        else:
            print(f"❌ Fichier {file_path} introuvable")
    else:
        print("❌ Pas de JSON dans la réponse")
        
except Exception as e:
    print(f"❌ Exception : {e}")
    exit(1)
