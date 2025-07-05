# fetch_data.py

import requests
import json
import os
from datetime import datetime, timedelta

# Pega a chave da API dos Secrets do GitHub
API_KEY = os.environ.get('API_SPORTS_KEY')
BASE_URL = f"https://www.thesportsdb.com/api/v1/json/{API_KEY}"

# IDs dos campeonatos que queremos
LEAGUE_IDS = [
    "4328", # UEFA Champions League
    "4335", # Brasileirão Serie A
    "4334", # Ligue 1 Francesa
    "4331", # Bundesliga Alemã
    "4332", # Serie A Italiana
    "4337", # Eredivisie Holandesa
    "4338", # Primeira Liga Portuguesa
    "4329", # UEFA Europa League
    "4413", # FIFA Club World Cup
    "4346", # Copa Libertadores
    "4344", # Campeonato Carioca
    "4391", # Copa do Mundo
]

# Função para buscar e salvar os dados de um endpoint
def fetch_and_save(endpoint, output_filename):
    try:
        url = f"{BASE_URL}/{endpoint}"
        print(f"Buscando dados de: {url}")
        response = requests.get(url)
        response.raise_for_status() # Lança um erro se a requisição falhar
        data = response.json()
        
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        print(f"Dados salvos em {output_filename}")

    except requests.exceptions.RequestException as e:
        print(f"Erro ao buscar dados para {endpoint}: {e}")

# Função principal
if __name__ == "__main__":
    # Cria uma pasta para os dados se não existir
    if not os.path.exists('data'):
        os.makedirs('data')

    # Busca os detalhes de todas as ligas
    fetch_and_save("all_leagues.php", "data/leagues.json")

    # Busca os próximos 15 jogos para cada liga
    for league_id in LEAGUE_IDS:
        fetch_and_save(f"eventsnextleague.php?id={league_id}", f"data/fixtures_{league_id}.json")
    
    print("Processo de busca de dados concluído.")
