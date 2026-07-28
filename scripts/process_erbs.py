import csv
import sqlite3
import os
import sys

# Paths
INPUT_CSV = os.path.expanduser('~/Downloads/Estacoes_SMP.csv')
OUTPUT_DB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'erbs_database.sqlite')

def process_erbs():
    print(f"Lendo {INPUT_CSV}...")
    if not os.path.exists(INPUT_CSV):
        print(f"Erro: Arquivo não encontrado em {INPUT_CSV}")
        sys.exit(1)

    os.makedirs(os.path.dirname(OUTPUT_DB), exist_ok=True)
    
    # Connect to DB
    conn = sqlite3.connect(OUTPUT_DB)
    cursor = conn.cursor()
    
    # Create table with spatial index (R-Tree equivalent or just normal index since SQLite R-Tree requires compilation flag)
    # We will use simple float indexes for lat/lon for basic bounding box queries
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS erbs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            operadora TEXT,
            tecnologias TEXT,
            endereco TEXT
        )
    ''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_erbs_lat ON erbs(latitude)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_erbs_lon ON erbs(longitude)')
    cursor.execute('DELETE FROM erbs') # Clear existing

    # Dictionary to deduplicate towers at same coordinate
    # key: (lat, lon) -> value: { 'operadoras': set(), 'tecs': set(), 'endereco': str }
    towers = {}
    
    with open(INPUT_CSV, 'r', encoding='utf-8', errors='ignore') as f:
        # Check first line for BOM
        first_line = f.readline()
        if first_line.startswith('\ufeff'):
            first_line = first_line[1:]
        
        headers = first_line.strip().split(';')
        
        try:
            idx_lat = headers.index('Latitude decimal')
            idx_lon = headers.index('Longitude decimal')
            idx_empresa = headers.index('Empresa Estação')
            idx_geracao = headers.index('Geração')
            idx_end = headers.index('EnderecoEstacao')
            idx_bairro = headers.index('EndBairro')
        except ValueError as e:
            print("Erro ao encontrar colunas:", e)
            return

        count = 0
        for line in f:
            parts = line.strip().split(';')
            if len(parts) <= max(idx_lat, idx_lon, idx_empresa, idx_geracao):
                continue
                
            lat_str = parts[idx_lat].replace(',', '.')
            lon_str = parts[idx_lon].replace(',', '.')
            
            try:
                lat = float(lat_str)
                lon = float(lon_str)
            except ValueError:
                continue
                
            # Skip invalid coordinates
            if lat == 0 or lon == 0 or lat > 5 or lat < -35 or lon > -30 or lon < -75:
                continue
                
            coord = (round(lat, 5), round(lon, 5))
            empresa = parts[idx_empresa]
            geracao = parts[idx_geracao]
            endereco = f"{parts[idx_end]} - {parts[idx_bairro]}"
            
            if coord not in towers:
                towers[coord] = {
                    'operadoras': set(),
                    'tecnologias': set(),
                    'endereco': endereco
                }
                
            if empresa: towers[coord]['operadoras'].add(empresa)
            if geracao: towers[coord]['tecnologias'].add(geracao)
            
            count += 1
            if count % 100000 == 0:
                print(f"Lidas {count} linhas...")
                
    print(f"Extraídas {len(towers)} torres únicas. Inserindo no banco SQLite...")
    
    # Bulk insert
    batch = []
    for coord, data in towers.items():
        operadoras = ", ".join(sorted(list(data['operadoras'])))
        tecs = ", ".join(sorted(list(data['tecnologias'])))
        batch.append((coord[0], coord[1], operadoras, tecs, data['endereco']))
        
    cursor.executemany('''
        INSERT INTO erbs (latitude, longitude, operadora, tecnologias, endereco)
        VALUES (?, ?, ?, ?, ?)
    ''', batch)
    
    conn.commit()
    conn.close()
    
    # Size check
    db_size = os.path.getsize(OUTPUT_DB) / (1024*1024)
    print(f"Concluído! Banco salvo em {OUTPUT_DB} ({db_size:.2f} MB)")

if __name__ == '__main__':
    process_erbs()
