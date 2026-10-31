from yandex_music import Client

def on_code(code):
    print(f'Открой {code.verification_url} и введи код: {code.user_code}')

client = Client()
token = client.device_auth(on_code=on_code)
print(f'Твой токен: {token.access_token}')