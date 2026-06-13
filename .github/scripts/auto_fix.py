import os, json, re, subprocess, requests
from pathlib import Path

logs = Path("build-output.log").read_text()[:8000]

response = requests.post(
    "https://api.deepseek.com/v1/chat/completions",
    headers={"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}"},
    json={
        "model": "deepseek-chat",
        "messages": [{
            "role": "user",
            "content": f"Analyse ces logs Android et retourne UNIQUEMENT ce JSON:\n{{\"file\":\"chemin\",\"fix\":\"code corrigé\"}}\n\nLogs:\n{logs}"
        }]
    }
)

result = response.json()["choices"][0]["message"]["content"]
json_match = re.search(r'\{.*\}', result, re.DOTALL)
if json_match:
    data = json.loads(json_match.group())
    file_path = Path(data["file"])
    if file_path.exists():
        content = file_path.read_text()
        file_path.write_text(data["fix"])
        subprocess.run(["git", "config", "user.name", "AI Bot"])
        subprocess.run(["git", "config", "user.email", "bot@ai.com"])
        subprocess.run(["git", "checkout", "-b", "ai-fix"])
        subprocess.run(["git", "add", "."])
        subprocess.run(["git", "commit", "-m", f"Fix: {data.get('error','')}"])
        subprocess.run(["git", "push", "origin", "ai-fix"])
        subprocess.run(["gh", "pr", "create", "--title", "AI Fix", "--body", "Correction automatique", "--base", "main"])
