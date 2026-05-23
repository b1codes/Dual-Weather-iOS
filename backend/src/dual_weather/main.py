from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from mangum import Mangum

from dual_weather.routers import health, locations, me
from dual_weather.schemas.errors import Problem

app = FastAPI(
    title="Dual Weather API",
    version="0.1.0",
)

ERROR_TYPE_BASE = "https://dualweather.app/errors"


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    problem = Problem(
        type=f"{ERROR_TYPE_BASE}/{exc.status_code}",
        title=str(exc.detail) if not isinstance(exc.detail, str) else _short_title(exc.status_code),
        status=exc.status_code,
        detail=str(exc.detail),
    )
    return JSONResponse(status_code=exc.status_code, content=problem.model_dump())


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    problem = Problem(
        type=f"{ERROR_TYPE_BASE}/validation",
        title="Invalid request payload",
        status=422,
        detail="; ".join(f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in exc.errors()),
    )
    return JSONResponse(status_code=422, content=problem.model_dump())


def _short_title(status_code: int) -> str:
    return {
        400: "Bad request",
        401: "Unauthenticated",
        403: "Forbidden",
        404: "Not found",
        409: "Conflict",
    }.get(status_code, "Error")


app.include_router(health.router)
app.include_router(me.router)
app.include_router(locations.router)


handler = Mangum(app, lifespan="off")
