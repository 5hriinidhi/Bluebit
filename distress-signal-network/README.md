<div align="center">

# 🚨 DIST.RESS Signal Network

### Unified National Emergency Communication & Alert Orchestration System

🏆 **Built for BlueBit 4.0 Hackathon** · 📌 **Problem Statement 08** · 👥 **Team Mario**

[![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.10-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![Redis](https://img.shields.io/badge/Redis-PubSub-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![OR--Tools](https://img.shields.io/badge/OR--Tools-TSP-4285F4?logo=google&logoColor=white)](https://developers.google.com/optimization)

</div>

---

## 🚀 The Elevator Pitch

**DIST.RESS** is an **AI-driven multi-channel emergency orchestration platform** designed to operate even when traditional infrastructure fails. It combines:

- 📡 Offline **acoustic mesh network** (Sonic Cascade) for trapped citizens
- 🤖 **Zero-latency NLP triage** for automatic threat detection & severity classification
- 🚨 **Decoupled broadcast engine** for instant multi-channel alert distribution
- 🛣️ **OR-Tools TSP routing** for optimal ambulance dispatch

Ensuring **life-saving alerts reach citizens even during infrastructure collapse.**

---

## 🏗️ System Architecture

```
┌─────────────────┐   ┌──────────────────┐   ┌─────────────────────┐
│  📱 Flutter App │   │ 📟 ESP32 / IoT   │   │ 🔊 Sonic Cascade    │
│  (Citizen SOS)  │   │      Nodes       │   │ (Offline Mesh Relay) │
└────────┬────────┘   └────────┬─────────┘   └──────────┬──────────┘
         │                     │                         │
         └─────────┬───────────┴─────────────────────────┘
                   ▼
┌──────────────────────────────────────────────────────────────────┐
│                   ⚙️ Node.js Orchestration API                  │
│   Express · PostgreSQL JSONB · Redis PubSub · Socket.io          │
│   POST /api/sos · PATCH /api/sos/:id/triage · POST /api/alert    │
└───────┬──────────────┬────────────────────────┬──────────────────┘
        │              │                        │
   Redis PubSub    WebSocket               HTTP calls
   (sos-events)    (new-sos,               (keep-warm,
                   triage-complete,         route optimise)
                   broadcast-alert)
        │              │                        │
        ▼              ▼                        ▼
┌───────────────┐ ┌─────────────────┐ ┌─────────────────────────┐
│ 🧠 FastAPI AI │ │ 💻 React        │ │ 📲 Broadcast Channels   │
│   Service     │ │ Command Center  │ │                         │
│               │ │                 │ │ • FCM Push Notifications│
│ • NLP Triage  │ │ • Mapbox GL     │ │ • WebSocket Feed        │
│ • Threat      │ │ • Live Heatmap  │ │ • MQTT → IoT Sirens     │
│   Monitor     │ │ • Alert Banner  │ │ • Cell Broadcast API    │
│ • OR-Tools    │ │ • Route Overlay │ │ • Telegram Bot          │
│   TSP Solver  │ │ • Severity      │ │                         │
│               │ │   Counters      │ │                         │
└───────────────┘ └─────────────────┘ └─────────────────────────┘
```

---

## 📁 Repository Structure

```
distress-signal-network/
├── ai/                    # 🧠 Python FastAPI — NLP triage, threat monitor, TSP solver
│   ├── distress_ai/       #    Core package (main.py, triage.py, solver.py, etc.)
│   ├── requirements.txt   #    Python dependencies
│   └── README.md          #    Detailed AI service documentation
│
├── backend/               # ⚙️ Node.js — Express API, Redis PubSub, PostgreSQL
│   ├── api/handlers/      #    Route handlers (sos.js, alert.js, routing.js)
│   ├── db/                #    PostgreSQL schema & migrations
│   ├── redis/             #    Publisher & subscriber modules
│   ├── ws/                #    Socket.io WebSocket server
│   └── server.js          #    Main entry point
│
├── frontend/              # 💻 React — Command Center Dashboard
│   ├── src/components/    #    MapView, AlertBanner, Sidebar, RoutingPanel
│   ├── src/hooks/         #    useMapData, useWebSocket
│   └── src/api/           #    Axios API client modules
│
├── mobile/                # 📱 Flutter — Citizen SOS App
│   └── distress_signal/   #    Flutter project (Dart)
│       ├── lib/screens/   #    Home screen, SOS history
│       ├── lib/services/  #    API, location, shake detector, sonic cascade
│       └── lib/widgets/   #    SOS button, connection dot, status card
│
├── iot/                   # 📟 ESP32 IoT node placeholder
├── docs/                  #    API contract JSON, playbook docs
└── esp32_simulator.py     #    Python ESP32 node simulator
```

---

## 🔌 API Endpoints

| Method  | Endpoint                  | Description                                        |
|---------|---------------------------|----------------------------------------------------|
| `GET`   | `/health`                 | Keep-warm ping — responds `{"status":"ok"}` < 100ms |
| `POST`  | `/api/sos`                | Submit SOS report (manual, zero-touch, IoT, sonic) |
| `PATCH` | `/api/sos/:id/triage`     | AI triage callback — sets severity, label, colour  |
| `GET`   | `/api/sos/heatmap`        | Fetch all SOS reports for initial map load          |
| `POST`  | `/api/alert/trigger`      | Fire emergency broadcast (confidence ≥ 0.85)       |
| `GET`   | `/api/routing/optimise`   | Compute optimal ambulance route via OR-Tools TSP   |
| `GET`   | `/api/alerts/recent`      | Recent verified broadcast alerts                   |
| `GET`   | `/api/sos/stats`          | Live severity & source counts for sidebar          |

---

## 🚦 Severity Classification

| Severity | Label                | Colour    | Description                           |
|----------|----------------------|-----------|---------------------------------------|
| 1        | CRITICAL — Trapped   | `#FF0000` | Person trapped/buried — highest priority |
| 2        | URGENT — Medical     | `#FF8800` | Injured/bleeding — needs ambulance    |
| 3        | STANDARD — Supplies  | `#FFFF00` | Food/water/shelter — lower priority   |
| null     | Awaiting Triage      | `#888888` | AI not yet classified (~500ms delay)  |

---

## 🌟 Bonus Features

### 📡 Sonic Cascade (Offline Mesh Network)
When cellular connectivity is lost, the phone emits **18–20kHz ultrasonic signals**. Nearby devices capture via microphone and relay SOS signals to cloud, creating a **self-healing emergency mesh network**.

### 🦾 Zero-Touch SOS
Using accelerometer + gyroscope + G-force threshold detection. If a user is **unconscious during a blast/crash**, the phone **automatically triggers SOS** — no human input required.

### 🚑 TSP Ambulance Routing
Using **Google OR-Tools** with a 3-second hard timeout, the system clusters SOS locations and calculates **optimal ambulance paths** minimizing total rescue time. Falls back to nearest-neighbour greedy algorithm if needed.

### 🗣️ Multi-Language Alerts
Alerts are automatically broadcast in **English**, **Hindi**, and **Marathi**.

---

## 💻 Tech Stack

| Layer        | Technology                                                    |
|--------------|---------------------------------------------------------------|
| **Mobile**   | Flutter 3.10 · Dart · sensors_plus · geolocator · BLE        |
| **Frontend** | React 19 · Mapbox GL JS · Socket.io · Mantine UI · Lucide    |
| **Backend**  | Node.js 20 · Express 5 · PostgreSQL · Redis · Socket.io      |
| **AI**       | Python 3.11 · FastAPI · OR-Tools · httpx · Pydantic v2       |
| **Infra**    | Railway (Backend + Redis + PostgreSQL) · Render (AI) · Vercel (Dashboard) |

---

## 🚀 Quick Start Guide

### Prerequisites
- **Node.js 20.x** and **npm**
- **Python 3.11+** and **pip**
- **Flutter 3.10+**
- **Redis** (or Railway Redis URL)
- **PostgreSQL** (or Railway PostgreSQL URL)

### 1. Backend (Node.js)
```bash
cd distress-signal-network/backend
cp .env.example .env          # Configure DB, Redis, etc.
npm install
npm run migrate               # Create PostgreSQL tables
npm start                     # Starts on port 3000
```

### 2. AI Service (Python)
```bash
cd distress-signal-network/ai
cp .env.example .env          # Set REDIS_URL, BACKEND_URL
pip install -r requirements.txt
uvicorn distress_ai.main:app --port 8001
```

### 3. Frontend (React)
```bash
cd distress-signal-network/frontend
npm install
npm start                     # Starts on port 3000
```

### 4. Mobile (Flutter)
```bash
cd distress-signal-network/mobile/distress_signal
flutter pub get
flutter run
```

---

## 🔗 Live Deployments

| Component                  | Status    | Platform  |
|----------------------------|-----------|-----------|
| ⚙️ Core Orchestration API | 🟢 Live  | Railway   |
| 🧠 AI Processing Engine   | 🟢 Live  | Render    |
| 💻 Command Center         | 🟢 Live  | Vercel    |
| 📱 Citizen App (APK)      | 🟢 Built | Flutter   |

---

## 🔄 Real-Time Data Flow

```
1. Citizen taps SOS → Flutter POST /api/sos
2. Backend saves to PostgreSQL → publishes to Redis 'sos-events'
3. Dashboard receives WebSocket 'new-sos' → grey marker appears
4. AI subscribes to Redis → runs NLP triage in < 500ms
5. AI PATCHes /api/sos/:id/triage → severity assigned
6. Dashboard receives 'triage-complete' → marker turns RED/ORANGE/YELLOW
7. Background monitor detects threat → POST /api/alert/trigger
8. Backend broadcasts alert → Dashboard banner flips RED 🚨
```

---

## 👥 Team Mario

| Member         | Role            | Responsibility                                     |
|----------------|-----------------|-----------------------------------------------------|
| **Shrinidhi**  | 🧠 AI Lead     | FastAPI NLP service, OR-Tools TSP, threat monitor   |
| **Aryan**      | ⚙️ Backend Lead | Node.js API, Redis PubSub, PostgreSQL, broadcasting |
| **Ajinkya**    | 💻 Frontend    | React dashboard, Mapbox heatmap, alert UI           |
| **Ajaya**      | 📱 Mobile      | Flutter citizen app, zero-touch, Sonic Cascade      |

---

<div align="center">

**Built with ❤️ under pressure at BlueBit 4.0**

</div>
