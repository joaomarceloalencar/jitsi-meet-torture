#!/usr/bin/env python3
"""
Jitsi Load Testing Script
Simula múltiplos usuários em conferências Jitsi usando Selenium WebDriver.
Gera carga real de CPU nos JVBs ao habilitar vídeo.

Usage:
    python3 jitsi_load_test.py --users 5 --duration 60
"""

import argparse
import jwt
import time
import threading
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, WebDriverException
from webdriver_manager.chrome import ChromeDriverManager
import os
import sys

# Configurações
JITSI_URL = "https://jitsi.macbookpro:30443"
JWT_SECRET_FILE = "/Users/jmhal/source/agencia/jitsi-scalability/jitsi-k8s/.secrets/jwt_app_secret"


def generate_jwt_token(username: str, role: str = "moderator", room: str = "*") -> str:
    """Gera token JWT para autenticação no Jitsi"""
    
    with open(JWT_SECRET_FILE, "r") as f:
        secret = f.read().strip()
    
    payload = {
        "iss": "jitsi-meet",
        "aud": "jitsi-meet",
        "sub": "jitsi.macbookpro",
        "room": room,
        "context": {
            "user": {
                "id": username,
                "name": username,
                "email": f"{username}@example.com",
                "moderator": role == "moderator"
            }
        },
        "iat": int(time.time()),
        "exp": int(time.time()) + 86400  # 24 horas
    }
    
    token = jwt.encode(payload, secret, algorithm="HS256")
    return token


def create_driver(user_id: int, headless: bool = True) -> webdriver.Chrome:
    """Cria instância do Chrome WebDriver
    
    Args:
        user_id: ID do usuário
        headless: Se True, usa modo headless. Se False, usa browser com GUI
    """
    
    options = Options()
    
    if headless:
        options.add_argument("--headless=new")
    else:
        # Browser com GUI - janela visível
        options.add_argument("--window-size=1280,720")
        # Desabilita barra de notícias
        options.add_argument("--disable-features=ChromeWhatsNewUI")
    
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    
    
    # Otimizações para reduzir uso de recursos
    options.add_argument("--disable-software-rasterizer")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-infobars")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-first-run")
    options.add_argument("--no-default-browser-check")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-setuid-sandbox")
    options.add_argument("--disable-accelerated-2d-canvas")
    options.add_argument("--disable-background-timer-throttling")
    options.add_argument("--disable-ipc-flooding-protection")
    options.add_argument("--disable-renderer-backgrounding")
    options.add_argument("--force-color-profile=srgb")
    options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")
    options.add_argument("--blink-settings=imagesEnabled=false")
    options.add_argument("--lang=en-US,en,generic")
    options.add_argument("--disable-dev-shm-usage")
    
    
    # Configurações de performance
    prefs = {
        "profile.default_content_setting_values.media_stream": 1,  # Permitir câmera/microfone
        "profile.default_content_setting_values.notifications": 2,
        "profile.default_content_setting_values.automatic_downloads": 1
    }
    options.add_experimental_option("prefs", prefs)
    
    # Desabilita permissão de câmera/microfone automaticamente
    options.add_argument("--use-fake-ui-for-media-stream")
    options.add_argument("--use-fake-device-for-media-stream")
    
    # Usar webdriver-manager para baixar versão correta automaticamente
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    driver.set_page_load_timeout(60)
    driver.set_script_timeout(60)
    
    # Aumentar timeouts do WebDriver
    driver.implicitly_wait(10)
    
    return driver


def join_conference(user_id: int, username: str, room_name: str, jwt_token: str, duration: int, results: dict, headless: bool = True):
    """
    Faz um usuário entrar em uma conferência Jitsi com vídeo ativo.
    
    Args:
        user_id: ID do usuário (para identificação)
        username: Nome do usuário
        room_name: Nome da sala
        jwt_token: Token JWT para autenticação
        duration: Duração em segundos que o usuário permanece na conferência
        results: Dict compartilhado para armazenar resultados
        headless: Se True, usa modo headless. Se False, usa browser com GUI
    """
    
    start_time = time.time()
    driver = None
    
    try:
        print(f"[{username}] Iniciando browser...")
        driver = create_driver(user_id)
        
        # Construir URL com token JWT
        url = f"{JITSI_URL}/{room_name}?jwt={jwt_token}"
        
        print(f"[{username}] Acessando: {url}")
        driver.get(url)
        
        # Esperar pela interface principal (timeout: 60s)
        WebDriverWait(driver, 60).until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )
        
        join_time = time.time() - start_time
        print(f"[{username}] Entrou na conferência em {join_time:.2f}s")
        
        results[user_id] = {
            "status": "joined",
            "join_time": join_time,
            "username": username
        }
        
        # Tentar ativar vídeo e áudio via JavaScript
        try:
            # Esperar pelo botão de câmera e ativar
            video_button = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, "[data-tooltip=\"Toggle Camera (Video)\"]"))
            )
            video_button.click()
            print(f"[{username}] Vídeo ativado")
        except:
            print(f"[{username}] Não conseguiu ativar vídeo (normal em automation)")
        
        # Manter na conferência pela duração especificada
        print(f"[{username}] Permanecendo na conferência por {duration}s...")
        time.sleep(duration)
        
        # Marcar como concluído
        results[user_id]["duration"] = duration
        results[user_id]["status"] = "completed"
        
        elapsed = time.time() - start_time
        print(f"[{username}] Concluído em {elapsed:.2f}s")
        
    except TimeoutException as e:
        error_msg = f"[{username}] Timeout: {str(e)}"
        print(error_msg)
        results[user_id] = {
            "status": "timeout",
            "error": str(e)
        }
        
    except WebDriverException as e:
        error_msg = f"[{username}] WebDriver error: {str(e)}"
        print(error_msg)
        results[user_id] = {
            "status": "webdriver_error",
            "error": str(e)
        }
        
    except Exception as e:
        error_msg = f"[{username}] Error: {str(e)}"
        print(error_msg)
        results[user_id] = {
            "status": "error",
            "error": str(e)
        }
        
    finally:
        if driver:
            try:
                driver.quit()
                print(f"[{username}] Browser fechado")
            except:
                pass


def run_load_test(num_users: int, duration: int, room_name: str = None, stagger_seconds: int = 2, headless: bool = True):
    """
    Executa teste de carga simulando múltiplos usuários.
    
    Args:
        num_users: Número de usuários simultâneos
        duration: Duração da conferência em segundos
        room_name: Nome da sala (gerado aleatoriamente se None)
        stagger_seconds: Segundos de intervalo entre cada usuário
        headless: Se True, usa modo headless. Se False, usa browser com GUI
    """
    
    if room_name is None:
        room_name = f"LoadTest_{int(time.time())}"
    
    mode = "HEADLESS" if headless else "COM GUI (Full Browser)"
    
    print("=" * 60)
    print("Jitsi Load Testing Script")
    print("=" * 60)
    print(f"URL: {JITSI_URL}")
    print(f"Sala: {room_name}")
    print(f"Usuários: {num_users}")
    print(f"Duração: {duration}s")
    print(f"Stagger: {stagger_seconds}s")
    print(f"Modo: {mode}")
    print("=" * 60)
    print()
    
    if not headless:
        print("⚠️  ATENÇÃO: Browsers com GUI serão abertos!")
        print("   Cada usuário consumirá ~500MB RAM + CPU para vídeo")
        print("   Recomendado máximo de 3-5 usuários simultâneos")
        print()
    
    # Verificar se o secret JWT existe
    if not os.path.exists(JWT_SECRET_FILE):
        print(f"ERRO: Secret JWT não encontrado em {JWT_SECRET_FILE}")
        print("Execute ./scripts/setup.sh primeiro")
        sys.exit(1)
    
    results = {}
    threads = []
    
    start_time = time.time()
    print(f"Início do teste: {datetime.now().strftime('%H:%M:%S')}")
    print()
    
    # Criar e iniciar threads para cada usuário
    for i in range(num_users):
        username = f"user{i+1}"
        jwt_token = generate_jwt_token(username, "moderator", room_name)
        
        thread = threading.Thread(
            target=join_conference,
            args=(i, username, room_name, jwt_token, duration, results, headless)
        )
        
        threads.append(thread)
        
        # Aguardar antes de iniciar o próximo usuário (para evitar conflito ChromeDriver)
        if i > 0:
            print(f"Aguardando {stagger_seconds}s antes de iniciar {username}...")
            time.sleep(stagger_seconds)
        
        thread.start()
        print(f"✓ Iniciado: {username} (thread {i+1}/{num_users})")
    
    print()
    print("Aguardando conclusão de todos os usuários...")
    print("-" * 60)
    
    # Esperar todas as threads terminarem
    for thread in threads:
        thread.join()
    
    total_time = time.time() - start_time
    
    # Exibir resultados
    print()
    print("=" * 60)
    print("RESULTADOS DO TESTE")
    print("=" * 60)
    
    completed = sum(1 for r in results.values() if r.get("status") == "completed")
    failed = num_users - completed
    
    print(f"Usuários bem-sucedidos: {completed}/{num_users}")
    print(f"Usuários com falha: {failed}")
    print(f"Tempo total: {total_time:.2f}s")
    print()
    
    # Detalhar resultados por usuário
    print("Detalhamento por usuário:")
    print("-" * 60)
    
    for user_id, result in sorted(results.items()):
        status = result.get("status", "unknown")
        username = result.get("username", f"user{user_id+1}")
        
        if status == "completed":
            join_time = result.get("join_time", 0)
            print(f"✓ {username}: Concluído (join: {join_time:.2f}s)")
        elif status == "timeout":
            print(f"✗ {username}: Timeout")
        else:
            error = result.get("error", "Unknown error")
            print(f"✗ {username}: {status} - {error[:50]}")
    
    print("=" * 60)
    print()
    print(f"Sala de teste: {JITSI_URL}/{room_name}")
    print("Monitore os JVBs com:")
    print("  kubectl top pods -n jitsi -l component=jvb")
    print("  kubectl get hpa jvb-hpa -n jitsi")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Jitsi Load Testing Script - Simula múltiplos usuários em conferências"
    )
    parser.add_argument(
        "--users", "-u",
        type=int,
        default=5,
        help="Número de usuários simultâneos (default: 5)"
    )
    parser.add_argument(
        "--duration", "-d",
        type=int,
        default=60,
        help="Duração em segundos (default: 60)"
    )
    parser.add_argument(
        "--room", "-r",
        type=str,
        default=None,
        help="Nome da sala (default: auto-generated)"
    )
    parser.add_argument(
        "--stagger", "-s",
        type=int,
        default=2,
        help="Intervalo entre usuários em segundos (default: 2)"
    )
    parser.add_argument(
        "--gui",
        action="store_true",
        default=False,
        help="Usar browsers com GUI (não headless) - gera carga real de vídeo"
    )
    
    args = parser.parse_args()
    
    run_load_test(
        num_users=args.users,
        duration=args.duration,
        room_name=args.room,
        stagger_seconds=args.stagger,
        headless=not args.gui
    )


if __name__ == "__main__":
    main()
