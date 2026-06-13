import os, json, re, subprocess, requests
from pathlib import Path

# Lire les logs
log_file = Path("build-output.log")
if not log_file.exists():
    print("❌ Fichier build-output.log introuvable")
    exit(1)

logs = log_file.read_text()
print(f"📖 Logs lus : {len(logs)} caractères")

# Extraire les erreurs importantes
error_lines = []
for line in logs.split("\n"):
    if "error" in line.lower() or "failed" in line.lower():
        error_lines.append(line)

error_summary = "\n".join(error_lines[-20:])  # Dernières 20 lignes d'erreur
print(f"🔍 Erreurs extraites : {len(error_lines)} lignes")

# Préparer la requête DeepSeek
api_key = os.environ.get('DEEPSEEK_API_KEY', '')
print(f"🔑 Clé API présente : {'OUI' if api_key else 'NON'}")

prompt = f"""Analyse ces erreurs de build Flutter et retourne UNIQUEMENT ce JSON:
{{"file":"chemin/du/fichier","description":"description de l'erreur","fix":"code corrigé complet"}}

Erreurs:
{error_summary[:5000]}
"""

print("🚀 Appel DeepSeek...")
try:
    response = requests.post(
        "https://api.deepseek.com/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        },
        json={
            "model": "deepseek-chat",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": 2000
        },
        timeout=60
    )
    
    print(f"📡 Statut HTTP : {response.status_code}")
    
    if response.status_code != 200:
        print(f"❌ Erreur API : {response.text}")
        exit(1)
    
    result = response.json()
    print(f"📦 Réponse reçue : {json.dumps(result, indent=2)[:500]}")
    
    content = result["choices"][0]["message"]["content"]
    print(f"💬 Contenu : {content[:500]}")
    
    # Extraire le JSON
    json_match = re.search(r'\{.*\}', content, re.DOTALL)
    if json_match:
        data = json.loads(json_match.group())
        file_path = Path(data.get("file", ""))
        
        if file_path.exists():
            print(f"🔧 Correction de {file_path}")
            file_path.write_text(data.get("fix", ""))
            
            # Git operations
            subprocess.run(["git", "config", "user.name", "AI Bot"], check=False)
            subprocess.run(["git", "config", "user.email", "bot@ai.com"], check=False)
            subprocess.run(["git", "checkout", "-b", "ai-fix"], check=False)
            subprocess.run(["git", "add", "."], check=False)
            subprocess.run(["git", "commit", "-m", f"Fix: {data.get('description','')}"], check=False)
            subprocess.run(["git", "push", "origin", "ai-fix"], check=False)
            subprocess.run(["gh", "pr", "create", "--title", "AI Fix", "--body", data.get('description',''), "--base", "main"], check=False)
            print("✅ PR créée !")
        else:
            print(f"❌ Fichier {file_path} introuvable")
    else:
        print("❌ Pas de JSON dans la réponse")
        print(f"Réponse brute : {content}")
        
except Exception as e:
    print(f"❌ Exception : {e}")
    exit(1)
