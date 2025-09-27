
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from typing import Dict, Any

app = FastAPI(title="Mock Astron-RPA Service")

class WorkflowRequest(BaseModel):
    action: str
    workflow_type: str
    components: list
    parameters: Dict[str, Any] = {}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "mock-astron-rpa"}

@app.post("/mcp")
async def mcp_endpoint(request: WorkflowRequest):
    return {
        "status": "success",
        "result": f"Mock execution of {request.workflow_type} with {len(request.components)} components",
        "components_used": request.components,
        "execution_time": 30
    }

@app.get("/components")
async def get_components():
    return {
        "ui_testing": ["rpabrowser", "rpacv", "rpawindow"],
        "api_testing": ["rpanetwork", "rpaopenapi"],
        "data_processing": ["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
        "ai_processing": ["rpaai", "rpaverifycode"],
        "system_automation": ["rpasystem", "rpaencrypt", "rpaemail", "rpaenterprise"]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8020)
