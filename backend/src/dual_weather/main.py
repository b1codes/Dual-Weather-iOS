from fastapi import FastAPI
from mangum import Mangum

from dual_weather.routers import health, me

app = FastAPI(
    title="Dual Weather API",
    version="0.1.0",
)

app.include_router(health.router)
app.include_router(me.router)


handler = Mangum(app, lifespan="off")
