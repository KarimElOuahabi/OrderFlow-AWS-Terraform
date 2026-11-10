"""Inline the icons in docs/icons into docs/architecture.template.html -> docs/orderflow-architecture.html"""
import base64, json, pathlib

root = pathlib.Path(__file__).parent
icons = root / "icons"

files = {
    "jenkins": "jenkins", "docker": "docker-icon", "terraform": "terraform-icon",
    "github": "github-icon", "gitlab": "gitlab-icon", "maven": "maven",
    "postgres": "postgresql", "python": "python", "lambda": "aws-lambda",
    "sqs": "aws-sqs", "eventbridge": "aws-eventbridge", "dynamodb": "aws-dynamodb",
    "ses": "aws-ses", "apigw": "aws-api-gateway", "cognito": "aws-cognito",
    "rds": "aws-rds", "elb": "aws-elb", "xray": "aws-xray", "s3": "aws-s3",
    "ecs": "aws-ecs", "fargate": "aws-fargate", "bedrock": "bedrock",
    "trivy": "trivy", "checkov": "checkov", "semgrep": "semgrep",
}

# Simple hand-drawn icons for tools that have no public logo in the icon sets.
custom = {
    "person": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="11" r="6" fill="#5a6b85"/><path d="M4 29c0-7 5-11 12-11s12 4 12 11z" fill="#5a6b85"/></svg>',
    "gitleaks": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="11" cy="16" r="7" fill="none" stroke="#1f9d55" stroke-width="3.5"/><path d="M17 16h12M24 16v6M29 16v4" stroke="#1f9d55" stroke-width="3.5" stroke-linecap="round" fill="none"/></svg>',
    "ecr": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="5" fill="#ed7100"/><path d="M16 6l9 4.5v11L16 26l-9-4.5v-11z" fill="none" stroke="#fff" stroke-width="2"/><path d="M7 10.5l9 4.5 9-4.5M16 15v11" stroke="#fff" stroke-width="2" fill="none"/></svg>',
}

data = {}
for key, name in files.items():
    data[key] = "data:image/svg+xml;base64," + base64.b64encode((icons / f"{name}.svg").read_bytes()).decode()
for key, svg in custom.items():
    data[key] = "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()

def inline(template, out):
    html = (root / template).read_text(encoding="utf-8")
    start = html.index("/*ICONS*/")
    end = html.index("/*END*/") + len("/*END*/")
    html = html[:start] + json.dumps(data) + html[end:]
    (root / out).write_text(html, encoding="utf-8")
    print("wrote", root / out, len(html) // 1024, "KB")


inline("architecture.template.html", "orderflow-architecture.html")
inline("carousel.template.html", "orderflow-carousel.html")

# Export the carousel slides as 2x PNGs (2160x2700) with headless Edge/Chrome.
import shutil, subprocess, sys

if "--png" in sys.argv:
    browser = next(
        (p for p in [
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        ] if pathlib.Path(p).exists()),
        shutil.which("msedge") or shutil.which("chrome"),
    )
    outdir = root / "slides"
    outdir.mkdir(exist_ok=True)
    page = (root / "orderflow-carousel.html").resolve().as_uri()
    for n in range(1, 6):
        png = outdir / f"orderflow-slide-{n}.png"
        subprocess.run([
            browser, "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--force-device-scale-factor=2", "--window-size=1080,1350",
            "--virtual-time-budget=3000", f"--screenshot={png}", f"{page}?s={n}",
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("exported", png)
