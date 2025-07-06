# fetch_data.py

import requests
import json
import os

# Pega a chave da API dos Secrets do GitHub
API_KEY = os.environ.get('API_SPORTS_KEY', '123') # Usa '123' como fallback para testes locais
BASE_URL = f"https://www.thesportsdb.com/api/v1/json/{API_KEY}"

def fetch_from_api(endpoint):
    try:
        url = f"{BASE_URL}/{endpoint}"
        print(f"Buscando dados de: {url}")
        response = requests.get(url, timeout=30)
        response.raise_for_status() # Lança um erro se a requisição falhar
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Erro ao buscar dados para {endpoint}: {e}")
        return None

def main():
    if not os.path.exists('data'):
        os.makedirs('data')

    # 1. Lê a configuração de ligas do repositório
    try:
        with open('leagues_config.json', 'r') as f:
            config = json.load(f)
        # Extrai apenas os IDs da lista de objetos
        league_ids = [league['id'] for league in config.get('leagues', [])]
        print(f"Ligas a serem processadas, conforme config: {league_ids}")
    except FileNotFoundError:
        print("Erro: leagues_config.json não encontrado. Abortando.")
        return
    except (KeyError, TypeError) as e:
        print(f"Erro ao ler o formato de leagues_config.json: {e}. Verifique se ele contém uma lista de objetos com a chave 'id'.")
        return

    # 2. Busca os detalhes de cada liga configurada
    all_leagues_data = []
    print("Buscando detalhes das ligas selecionadas...")
    for league_id in set(league_ids): # Usamos set() para evitar buscar o mesmo ID duas vezes
        league_details_data = fetch_from_api(f"lookupleague.php?id={league_id}")
        if league_details_data and league_details_data.get('leagues'):
            all_leagues_data.extend(league_details_data['leagues'])

    # 3. Salva um arquivo consolidado com os detalhes das ligas
    with open('data/leagues.json', 'w', encoding='utf-8') as f:
        json.dump({'leagues': all_leagues_data}, f, ensure_ascii=False, indent=2)
    print("Arquivo consolidado 'data/leagues.json' criado com sucesso.")

    # 4. Busca os próximos jogos para cada liga configurada
    for league_id in set(league_ids):
        fixtures_data = fetch_from_api(f"eventsnextleague.php?id={league_id}")
        if fixtures_data:
            with open(f"data/fixtures_{league_id}.json", 'w', encoding='utf-8') as f:
                json.dump(fixtures_data, f, ensure_ascii=False, indent=2)
            print(f"Jogos salvos para a liga {league_id}")

    print("Processo de busca de dados concluído.")

if __name__ == "__main__":
    main()
