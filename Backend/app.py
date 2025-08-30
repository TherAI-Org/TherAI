from fastapi import FastAPI


app = FastAPI(title="TherAI Backend", version="0.1.0")


@app.get("/")
def read_root():
    return {"message": "TherAI backend is running"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


