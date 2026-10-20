from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = "PASTE_YOUR_RAPIDAPI_KEY_HERE"

@app.get("/")
def home():
    return {"message": "CareerConnect Backend Running"}

@app.get("/recommend")
def recommend(user_skills: str):
    url = "https://jsearch.p.rapidapi.com/search"

    querystring = {
        "query": user_skills + " jobs in india",
        "page": "1",
        "num_pages": "1"
    }

    headers = {
        "X-RapidAPI-Key": API_KEY,
        "X-RapidAPI-Host": "jsearch.p.rapidapi.com"
    }

    response = requests.get(url, headers=headers, params=querystring)
    data = response.json()

    results = []

    for job in data.get("data", [])[:10]:
        results.append({
            "title": job.get("job_title", "No Title"),
            "company": job.get("employer_name", "Unknown"),
            "location": job.get("job_city", "Unknown"),
            "link": job.get("job_apply_link", ""),
            "match_score": 0.9
        })

    return {"recommended_opportunities": results}