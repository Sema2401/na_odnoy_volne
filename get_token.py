from yandex_music import Client

def on_code(code):
    print(f"\n1. Открой эту ссылку в браузере: {code.verification_url}")
    print(f"2. Введи этот код: {code.user_code}\n")

print("Запускаю авторизацию...")
client = Client()
token = client.device_auth(on_code=on_code)

print("\n--- ГОТОВО! Твой токен: ---")
print(f"Access Token: {token.access_token}")
print(f"Refresh Token: {token.refresh_token}")