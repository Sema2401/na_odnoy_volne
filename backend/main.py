from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from yandex_music import Client
import os
import httpx

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

TOKEN = os.getenv("YM_TOKEN", "y0__wgBEPKJtY4FGN74BiCDu4TMGfZwUgjV_8SpIz7eGj7-jwzAQyo-")
client = Client(TOKEN).init()

@app.get("/search")
def search_track(query: str):
    try:
        search_result = client.search(query)
        if not search_result.tracks or not search_result.tracks.results:
            return {"error": "Ничего не найдено"}

        track = search_result.tracks.results[0]
        download_info = track.get_download_info(get_direct_links=True)
        direct_url = download_info[0].direct_link

        return {
            "title": track.title,
            "artist": track.artists[0].name,
            "url": direct_url
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/stream")
async def stream_track(url: str):
    try:
        async with httpx.AsyncClient() as client_http:
            req = await client_http.get(url, follow_redirects=True)
            req.raise_for_status()

            headers = {
                "Content-Type": "audio/mpeg",
                "Content-Length": str(len(req.content)),
                "Accept-Ranges": "bytes"
            }
            return Response(content=req.content, headers=headers, media_type="audio/mpeg")
    except Exception as e:
        return Response(content=f"Error: {str(e)}", status_code=500)

