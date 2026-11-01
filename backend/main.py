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

# Токен только из переменной окружения (не храним его в коде).
TOKEN = os.environ["YM_TOKEN"]
client = Client(TOKEN).init()

UNKNOWN_GENRE = "other"
UNKNOWN_LABEL = "Другое"

# Запасной словарь код -> название. Основной берётся из client.genres() (см. _load_labels).
# Если кода нет ни там, ни там, в качестве названия отдаём сам код.
FALLBACK_LABELS = {
    "rock": "Рок",
    "pop": "Поп",
    "electronics": "Электроника",
    "metal": "Метал",
    "jazz": "Джаз",
    "classical": "Классика",
    "folk": "Фолк",
    "rnb": "R&B",
    "rusrap": "Русский рэп",
    "foreignrap": "Зарубежный рэп",
    "rusrock": "Русский рок",
    "ruspop": "Русский поп",
    "blues": "Блюз",
    "reggae": "Регги",
    "country": "Кантри",
    "soundtrack": "Саундтреки",
    "alternative": "Альтернатива",
    "indie": "Инди",
    "dance": "Танцевальная",
    UNKNOWN_GENRE: UNKNOWN_LABEL,
}


def _genre_title(g):
    """Русское название жанра из объекта yandex_music.Genre (с защитой от разных форматов)."""
    titles = getattr(g, "titles", None) or {}
    ru = titles.get("ru") if isinstance(titles, dict) else None
    title = getattr(ru, "title", None) or getattr(g, "title", None)
    return title


def _load_labels():
    labels = dict(FALLBACK_LABELS)

    def walk(genres):
        for g in genres or []:
            gid = getattr(g, "id", None)
            title = _genre_title(g)
            if gid and title:
                labels[gid] = title
            walk(getattr(g, "sub_genres", None))

    try:
        walk(client.genres())
    except Exception as e:  # сеть/формат ответа — остаёмся на запасном словаре
        print(f"genres() недоступен, используем запасной словарь: {e}")
    return labels


LABELS = _load_labels()


def _tag(code):
    code = code or UNKNOWN_GENRE
    return {"id": code, "label": LABELS.get(code, code)}


def _track_genre(track):
    for album in track.albums or []:
        if album.genre:
            return album.genre
    return UNKNOWN_GENRE


def _first_track(query: str):
    result = client.search(query)
    if not result.tracks or not result.tracks.results:
        return None
    return result.tracks.results[0]


@app.get("/genres")
def list_genres():
    """Все известные жанры-теги: [{id, label}], отсортированы по названию."""
    items = [{"id": k, "label": v} for k, v in LABELS.items()]
    return sorted(items, key=lambda x: x["label"].lower())


@app.get("/genre")
def track_genre(query: str):
    """Лёгкий запрос: только жанр трека (без ссылки на аудио)."""
    try:
        track = _first_track(query)
        if track is None:
            return {"error": "Ничего не найдено"}
        tag = _tag(_track_genre(track))
        return {"genre": tag["id"], "genre_label": tag["label"]}
    except Exception as e:
        return {"error": str(e)}


@app.get("/search")
def search_track(query: str):
    try:
        track = _first_track(query)
        if track is None:
            return {"error": "Ничего не найдено"}

        download_info = track.get_download_info(get_direct_links=True)
        direct_url = download_info[0].direct_link
        tag = _tag(_track_genre(track))

        return {
            "title": track.title,
            "artist": track.artists[0].name,
            "url": direct_url,
            "genre": tag["id"],
            "genre_label": tag["label"],
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
                "Accept-Ranges": "bytes",
            }
            return Response(content=req.content, headers=headers, media_type="audio/mpeg")
    except Exception as e:
        return Response(content=f"Error: {str(e)}", status_code=500)
