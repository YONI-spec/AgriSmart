import ai_edge_litert.interpreter as tflite
from fastapi import FastAPI

# C'est CETTE ligne qui manque ou qui est mal nommée
app = FastAPI() 

@app.get("/")
def read_root():
    return {"message": "AgriSmart API Online"}