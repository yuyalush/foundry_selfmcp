"""
deploy_agent.py - Azure AI Foundry にエージェントを登録するスクリプト

使用方法:
    python agents/deploy_agent.py \
        --project-endpoint <Foundry Project endpoint> \
        --mcp-server-url <APIM Gateway URL>/mcp

前提:
    - az login / azd auth login が完了していること
    - Foundry Project への Azure AI Agent Service 権限があること
"""
import argparse
import json
import os
import sys
from pathlib import Path

import yaml
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential


def load_agent_definition(yaml_path: str) -> dict:
    with open(yaml_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def build_mcp_tool_config(agent_def: dict, mcp_server_url: str) -> list[dict]:
    """エージェント定義から MCP ツール設定を構築する"""
    tools = []
    for tool in agent_def.get("tools", []):
        if tool.get("type") == "mcp":
            # URL テンプレートを実際の URL に置換
            server_url = tool["server"]["url"].replace("${MCP_SERVER_URL}", mcp_server_url)
            tools.append(
                {
                    "type": "mcp",
                    "server_label": tool["name"],
                    "server_url": server_url,
                    "allowed_tools": tool.get("available_tools", []),
                }
            )
    return tools


def deploy_agent(project_endpoint: str, mcp_server_url: str, agent_yaml: str) -> None:
    agent_def = load_agent_definition(agent_yaml)
    mcp_tools = build_mcp_tool_config(agent_def, mcp_server_url)

    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=project_endpoint, credential=credential)

    # 既存エージェントの確認
    existing_agents = list(client.agents.list_agents())
    existing = next(
        (a for a in existing_agents if a.name == agent_def["name"]),
        None,
    )

    agent_params = {
        "model": agent_def["model"]["deployment_name"],
        "name": agent_def["name"],
        "description": agent_def["description"],
        "instructions": agent_def["system_prompt"],
        "tools": mcp_tools,
        "metadata": agent_def.get("metadata", {}),
    }

    if existing:
        print(f"Updating existing agent: {existing.id}")
        agent = client.agents.update_agent(agent_id=existing.id, **agent_params)
        print(f"Agent updated: {agent.id}")
    else:
        print("Creating new agent...")
        agent = client.agents.create_agent(**agent_params)
        print(f"Agent created: {agent.id}")

    print(f"Agent name: {agent.name}")
    print(f"Agent ID:   {agent.id}")

    # エージェント ID を .azure 設定に保存
    env_file = Path(".azure") / "agent_config.json"
    env_file.parent.mkdir(exist_ok=True)
    config = {}
    if env_file.exists():
        config = json.loads(env_file.read_text(encoding="utf-8"))
    config["agent_id"] = agent.id
    config["project_endpoint"] = project_endpoint
    env_file.write_text(json.dumps(config, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Agent config saved to {env_file}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Deploy Azure AI Foundry Agent")
    parser.add_argument("--project-endpoint", required=True, help="AI Foundry Project endpoint URL")
    parser.add_argument("--mcp-server-url", required=True, help="MCP Server URL (via APIM)")
    parser.add_argument(
        "--agent-yaml",
        default="agents/data-agent.yaml",
        help="Path to agent definition YAML (default: agents/data-agent.yaml)",
    )
    args = parser.parse_args()

    deploy_agent(
        project_endpoint=args.project_endpoint,
        mcp_server_url=args.mcp_server_url,
        agent_yaml=args.agent_yaml,
    )


if __name__ == "__main__":
    main()
