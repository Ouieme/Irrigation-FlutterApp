import joblib
import pandas as pd
import re
import requests
import numpy as np
import firebase_admin
import traceback
import json
from pprint import pprint
from flask import Flask, request, jsonify
from rasterio.io import MemoryFile
from datetime import datetime, timezone
from firebase_admin import credentials, db

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads'
API_KEY = "685bd1ac1336b62bd966721b510f67ad"
GOOGLE_API_KEY = "AIzaSyCYiOuP4ly6RZul7BsMdHso0T4vLyNfenE"
OPENWEATHERMAP_API_KEY = "685bd1ac1336b62bd966721b510f67ad"
PLANT_ID_API_KEY ="L9TWkSuDnnEOps88cClv6rUNGAK0PQJ7CzCPJ65i2SUJLftR3t"
BASE_URL = "https://api.openepi.io/soil/property"

# 🔐 Initialisation Firebase
cred = credentials.Certificate("C:\\Users\\PC\\Downloads\\irrigo-3d24f-firebase-adminsdk-fbsvc-44fd86aaa1.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://irrigo-3d24f-default-rtdb.firebaseio.com'
})

latitude=36.3182022
longitude=6.6918667


@app.route('/')
def home():
    return "Bienvenue sur l'API d'Irrigation ! 🚀"



KNOWN_CROPS = [
    "wheat", "barley", "oats", "triticale", "corn", "sorghum", "potato",
    "lentil", "chick-pea", "pea", "peanut", "garlic", "artichoke", "carrot",
    "cabbage", "broccoli", "red beet", "onion", "watermelon", "melon",
    "celery", "leek", "turnip", "eggplant", "bean", "pumpkin", "cucumber",
    "tomato", "chilli", "fennel", "cardoon", "strawberry","maize",
]
CROP_ALIASES = {
    "maize": "maize",
    "corn": "maize",
    "winter squash": "pumpkin",
    "wild celery" : "celery",
    "brinjal": "eggplant",
    "common oat" : "oats",
    "common wh" : "wheat",
    "maize" : "corn",
    "corn" : "corn",
    "melon" : "melon",
    "aubergine": "eggplant",
    "cayenne pepper": "chilli",
    "garden tomato":"tomato",
    "cultivated garlic" : "garlic",
    "garden onion" : "onion",
    "wild carrot" : "carrot",
}

#---------- get growth stage ------------------------
def get_growth_stage_from_file(crop_name, lat, lon, today=None):
    today = today or datetime.now().date()
    current_year = today.year
    crop_name = crop_name.strip().lower()

    # Chemin absolu vers ton fichier CSV
    file_path = r"D:\\flutter_projects\\irrigo\\flask_api\\Crop_Calendar_Cleaned_Growth_Stages.csv"

    try:
        df = pd.read_csv(file_path, parse_dates=[
            'Planting Date', 'Initial End', 'Development End', 'Mid End', 'Late End', 'Harvest Date'
        ])
    except Exception as e:
        return f"Error loading file: {e}"

    # Nettoyer les noms de cultures et vérifier si crop_name est dans la cellule
    df['Crop_clean'] = df['Crop'].astype(str).str.lower().str.strip()

    # Garder les lignes où le crop_name est présent dans la colonne "Crop"
    filtered = df[df['Crop_clean'].str.contains(rf'\b{re.escape(crop_name)}\b')]

    if filtered.empty:
        return f"No calendar info found for crop: {crop_name}"

    # Filtrer par localisation
    location_match = filtered[
        (filtered['Lat_min'] <= lat) & (lat <= filtered['Lat_max']) &
        (filtered['Lon_min'] <= lon) & (lon <= filtered['Lon_max'])
    ]

    if location_match.empty:
        return f"No matching location for crop '{crop_name}' at lat={lat}, lon={lon}"

    # Prendre la première ligne qui correspond
    match = location_match.iloc[0]

    def align_to_current_year(dt):
        return dt.replace(year=current_year)

    try:
        stage_dates = {
            'initial': (
                align_to_current_year(match['Planting Date'].date()),
                align_to_current_year(match['Initial End'].date())
            ),
            'development': (
                align_to_current_year(match['Initial End'].date()),
                align_to_current_year(match['Development End'].date())
            ),
            'mid': (
                align_to_current_year(match['Development End'].date()),
                align_to_current_year(match['Mid End'].date())
            ),
            'late': (
                align_to_current_year(match['Mid End'].date()),
                align_to_current_year(match['Harvest Date'].date())
            )
        }
        # Déterminer dans quelle période tombe la date actuelle
        for stage, (start, end) in stage_dates.items():
            if start <= today <= end:
                return stage

        return "out of session"
    except Exception as e:
        return f"Error while determining growth stage: {e}"


#-------------- identify crop type ---------------
@app.route('/identify', methods=['POST'])
def identify():
    data = request.get_json()
    if not data or 'crop' not in data:
        return jsonify({"error": "Missing 'crop' in request"}), 400

    crop_name = data['crop'].lower()
    print(f"Nom de la culture reçu : {crop_name}")

    # Chercher dans les alias
    standard_crop = CROP_ALIASES.get(crop_name)

    # Sinon, chercher dans les cultures connues
    if not standard_crop:
        standard_crop = next((crop for crop in KNOWN_CROPS if crop.lower() in crop_name), None)

    if not standard_crop:
        return jsonify({"error": "Crop not recognized"}), 400


    today = datetime.now().date()

    # Appel de la fonction pour déterminer le stade
    stage = get_growth_stage_from_file(standard_crop, latitude, longitude, today)

    return jsonify({
        "crop": standard_crop,
        "stage": stage,
        "lat": latitude,
        "lon": longitude,
        "date": str(today)
    })


def get_soil_property(lat, lon, prop):
    params = {
        "lat": lat,
        "lon": lon,
        "depths": "0-5cm",
        "properties": prop,
        "values": "mean"
    }
    response = requests.get(BASE_URL, params=params)
    response.raise_for_status()
    data = response.json()

    print(f"Réponse JSON pour {prop} :")
    print(json.dumps(data, indent=2))

    try:
        layer = next((l for l in data["properties"]["layers"] if l["code"] == prop), None)
        if not layer:
            print(f"Aucun layer trouvé pour {prop}")
            return None

        if not layer.get("depths") or len(layer["depths"]) == 0:
            print(f"Aucune profondeur trouvée pour {prop}")
            return None

        mean_value = layer["depths"][0]["values"].get("mean")
        conversion_factor = layer["unit_measure"].get("conversion_factor")

        if mean_value is None or conversion_factor in (None, 0):
            print(f"Valeurs nulles ou invalides pour {prop} : mean={mean_value}, factor={conversion_factor}")
            return None

        mean_percent = mean_value / conversion_factor
        print(f"{prop.capitalize()} récupéré: {mean_percent:.2f}%")
        return mean_percent

    except (KeyError, IndexError, TypeError) as e:
        print(f"Erreur récupération de {prop}: {e}")
        return None


#------------------estimate soil type--------------------
@app.route('/soil-composition', methods=['GET'])
def soil_composition():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)

    if lat is None or lon is None:
        return jsonify({"error": "Veuillez fournir les paramètres 'lat' et 'lon'"}), 400

    sand = get_soil_property(lat, lon, "sand")
    silt = get_soil_property(lat, lon, "silt")
    clay = get_soil_property(lat, lon, "clay")

    print(f"Valeurs du sol récupérées : sand={sand:.2f}%, silt={silt:.2f}%, clay={clay:.2f}%")

    if None in (sand, silt, clay):
        return jsonify({"error": "Impossible de récupérer toutes les valeurs du sol"}), 500

    return jsonify({
        "latitude": lat,
        "longitude": lon,
        "soil_composition_percent": {
            "sand": round(sand, 2),
            "silt": round(silt, 2),
            "clay": round(clay, 2)
        }
    })


#---------------- estimate bulk density -----------------------
def estimate_bulk_density(sand, silt, clay):
    # Option 1 : formule simple à base de clay seulement
    bd1 = 1.3 - 0.0016 * clay

    # Option 2 : formule plus précise à base de sand et silt
    bd2 = 1.636 - 0.0036 * sand - 0.0050 * silt

    print(f"BD par formule clay-only : {bd1:.2f} g/cm³")
    print(f"BD par formule sand/silt : {bd2:.2f} g/cm³")

    return (bd1 + bd2) / 2




#----------------- update firebase ------------------------
@app.route('/update_firebase', methods=['POST'])
def update_firebase():
    data = request.get_json()
    print("✅ Payload reçu du client :", data)

    if not data:
        return jsonify({"error": "Requête vide"}), 400

    # Lecture du timestamp (obligatoire)
    timestamp_raw = data.get("timestamp")
    if not timestamp_raw:
        print("Timestamp absent, génération automatique.")
        timestamp_raw = datetime.utcnow().strftime("%Y-%m-%dT%H_%M_%S")
    timestamp = re.sub(r'[:.]', '_', timestamp_raw)

    # Lecture des capteurs ESP
    temperature_sensor = data.get("temperature_sensor")
    humidity_sensor = data.get("humidity_sensor")
    soil_moisture = data.get("soil_moisture")

    # Lecture position
    lat = data.get("latitude", latitude)
    lon = data.get("longitude", longitude)

    # Lecture culture
    crop_name = data.get("crop")
    detected_crop = None
    if crop_name:
        crop_name = crop_name.lower()
        print(f"Nom de la culture reçu : {crop_name}")
        detected_crop = CROP_ALIASES.get(crop_name)
        if not detected_crop and crop_name in KNOWN_CROPS:
            detected_crop = crop_name
        if detected_crop:
            print(f"Culture identifiée : {detected_crop}")
        else:
            print(f"⚠️ Culture non reconnue, ignorée.")

    print("✅ Requête reçue :", data)

    try:
        # Récupération météo
        weather_url = (
            f"http://api.openweathermap.org/data/2.5/weather?"
            f"lat={lat}&lon={lon}&appid={OPENWEATHERMAP_API_KEY}&units=metric"
        )
        weather_data = requests.get(weather_url).json()
        temp = weather_data.get("main", {}).get("temp", 0.0)
        humidity = weather_data.get("main", {}).get("humidity", 0.0)
        wind_speed = weather_data.get("wind", {}).get("speed", 0.0)
        pressure = weather_data.get("main", {}).get("pressure", 1013.25)
        precipitation = weather_data.get("rain", {}).get("1h", 0.0)

        # Rayonnement solaire (UVI)
        uvi_url = (
            f"http://api.openweathermap.org/data/2.5/uvi?"
            f"lat={lat}&lon={lon}&appid={OPENWEATHERMAP_API_KEY}"
        )
        uvi_data = requests.get(uvi_url).json()
        solar_energy = round(uvi_data.get("value", 0.0) * 25.0, 2)

        # Propriétés du sol
        sand = get_soil_property(lon, lat, "sand")
        silt = get_soil_property(lon, lat, "silt")
        clay = get_soil_property(lon, lat, "clay")
        print(f"🔍 Sol : sand={sand:.2f}%, silt={silt:.2f}%, clay={clay:.2f}%")

        max_component = max(sand, silt, clay)
        Soil_Type = (
            "sand" if max_component == sand else
            "silt" if max_component == silt else
            "clay"
        )
        Bulk_Density = estimate_bulk_density(sand, silt, clay)

        # Préparation des données
        update_data = {
            "temperature": temperature_sensor,
            "humidity": humidity_sensor,
            "soil_moisture": soil_moisture,
            "Tair_f_tavg": temp,
            "Qair_f_tavg": humidity,
            "Wind_f_tavg": wind_speed,
            "SWdown_f_tavg": solar_energy,
            "Rainf_f_tavg": precipitation,
            "Psurf_f_tavg": pressure,
            "Bulk_Density": Bulk_Density,
            "Soil_Type": Soil_Type,
            "clay": clay,
            "Silt": silt,
            "Sand": sand,
        }

        if detected_crop:
            update_data["crop"] = detected_crop

        # Stade de croissance
        stage = get_growth_stage_from_file(detected_crop, lat, lon)
        update_data["growth_stage"] = stage
        print(f"🌱 Stade de croissance : {stage}")

        # Appel interne au modèle de prédiction
        predict_payload = update_data.copy()
        predict_payload["crop"] = detected_crop
        predict_payload["growth_stage"] = stage
        predict_payload["soil_moisture"] = soil_moisture

        try:
            predict_response = requests.post("http://127.0.0.1:5000/predict", json=predict_payload)
            predict_result = predict_response.json()

            if predict_response.status_code == 200:
                recommended_quantity = predict_result.get("recommended_quantity", 0.0)
                irrigation_needed = predict_result.get("irrigation_needed", False)
                print(f"💧 Quantité recommandée : {recommended_quantity} mm/day")
                update_data["irrigation_quantity"] = recommended_quantity
                update_data["irrigation_needed"] = irrigation_needed
            else:
                print("⚠️ Erreur dans la réponse /predict :", predict_result)
        except Exception as e:
            print("❌ Échec de l'appel à /predict :", e)

        # Mise à jour Firebase
        ref = db.reference(f"/Data/drR4fJPQceOcaGxBxXgpwYVXldG2/{timestamp}")
        ref.update(update_data)

        return jsonify({
            "status": "OK",
            "timestamp": timestamp,
            "data": update_data
        }), 200

    except requests.exceptions.RequestException as e:
        print("❌ Erreur API externe :", e)
        traceback.print_exc()
        return jsonify({"error": "Erreur API externe", "details": str(e)}), 500

    except Exception as e:
        print("❌ Erreur serveur interne :", e)
        traceback.print_exc()
        return jsonify({"error": "Erreur serveur interne", "details": str(e)}), 500





#------------------Model prediction-----------------
print("Chargement du modèle et des encodeurs...")
model = joblib.load("D:\\best_model_random_forest.pkl")

# Nouveau : charger seulement l'encodeur de crop séparément
le_crop = joblib.load("D:\\label_encoder_crop.pkl")

# Charger les autres encodeurs depuis le fichier groupé
label_encoders = joblib.load("D:\\label_encoders.pkl")
le_stage = label_encoders["stage"]
le_soil = label_encoders["Soil_Texture"]

def convert_units(firebase_data):
    return {
        "Bulk_Density": firebase_data["Bulk_Density"],
        "Clay": firebase_data["clay"],
        "Psurf_f_tavg": firebase_data["Psurf_f_tavg"] * 100,
        "Qair_f_tavg": firebase_data["Qair_f_tavg"] / 100,
        "Rainf_f_tavg": firebase_data["Rainf_f_tavg"] / 86400,
        "SWdown_f_tavg": firebase_data["SWdown_f_tavg"],
        "Sand": firebase_data["Sand"],
        "Silt": firebase_data["Silt"],
        "Tair_f_tavg": firebase_data["Tair_f_tavg"] + 273.15,
        "Wind_f_tavg": firebase_data["Wind_f_tavg"],
        "crop": firebase_data["crop"],
        "stage": firebase_data["growth_stage"],
        "Soil_Texture": firebase_data["Soil_Type"],
        "SoilMoi00_10cm_tavg": firebase_data["soil_moisture"] / 10000
    }



@app.route('/predict', methods=['POST'])
def predict():
    try:
        content = request.get_json()
        if "humidity" in content:
            content.pop("humidity")

        print("\n📥 Requête reçue sur /predict")
        print("🧾 Données brutes reçues :")
        pprint(content)
        

        data = convert_units(content)
        print("\n🔁 Données après conversion d'unités :")
        pprint(data)
        # data["crop"] = normalize_crop_name(data["crop"])

        for enc_name, value, encoder in [
            ("crop", data["crop"], le_crop),
            ("stage", data["stage"], le_stage),
            ("Soil_Texture", data["Soil_Texture"], le_soil)
        ]:
            if value not in encoder.classes_:
                print(f"❗ Valeur inconnue pour {enc_name}: {value}")
                return jsonify({"error": f"Valeur inconnue pour {enc_name}: {value}"}), 400

        data["crop"] = le_crop.transform([data["crop"]])[0]
        data["stage"] = le_stage.transform([data["stage"]])[0]
        data["Soil_Texture"] = le_soil.transform([data["Soil_Texture"]])[0]

        feature_names = [
            "SoilMoi00_10cm_tavg", "Tair_f_tavg", "Qair_f_tavg", "Wind_f_tavg",
            "SWdown_f_tavg", "Rainf_f_tavg", "Psurf_f_tavg",
            "crop", "stage", "Bulk_Density", "Soil_Texture"
        ]
        input_data = np.array([[data[feat] for feat in feature_names]])

        print("\n📊 Données utilisées pour la prédiction :")
        for name, val in zip(feature_names, input_data[0]):
            print(f"   - {name}: {val}")

        prediction = float(model.predict(input_data)[0])
        irrigation_needed = bool(prediction > 0)
        recommended_quantity = round(prediction, 2) if irrigation_needed else 0.0

        print("\n🌾 Résultat de la prédiction :")
        print(f"   - Irrigation requise : {'✅ Oui' if irrigation_needed else '❌ Non'}")
        print(f"   - Quantité recommandée : {recommended_quantity} ml/day\n")

        return jsonify({
            "irrigation_needed": irrigation_needed,
            "recommended_quantity": float(recommended_quantity),
            "unit": "ml/day",
            "input_used": {k: float(v) if isinstance(v, (np.integer, np.floating)) else v for k, v in data.items()}
        })

    except Exception as e:
        print("❌ Erreur lors de la prédiction :", e)
        return jsonify({"error": "Erreur serveur", "details": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)