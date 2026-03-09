"""
Application Insights テレメトリ設定
最小限のトレーシングとロギング
"""

import logging
import os

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

logger = logging.getLogger(__name__)


def configure_telemetry() -> None:
    """Application Insights への OpenTelemetry テレメトリを設定する"""
    connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")

    if not connection_string:
        logger.warning(
            "APPLICATIONINSIGHTS_CONNECTION_STRING not set. Telemetry disabled."
        )
        return

    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor(
            connection_string=connection_string,
            # 個人情報保護のため SQL クエリの記録は無効化
            enable_live_metrics=False,
        )
        logger.info("Application Insights telemetry configured.")
    except ImportError:
        logger.warning("azure-monitor-opentelemetry not installed. Telemetry disabled.")
    except Exception as e:
        logger.error(f"Failed to configure telemetry: {e}")


def get_tracer(name: str) -> trace.Tracer:
    """OpenTelemetry Tracer を取得する"""
    return trace.get_tracer(name)


def record_tool_call(
    tracer: trace.Tracer,
    tool_name: str,
    success: bool,
    duration_ms: float,
    row_count: int = 0,
) -> None:
    """
    ツール呼び出しの最小限のトレーシングを記録する。
    入力データ・返却データは記録しない（プライバシー保護）。
    """
    with tracer.start_as_current_span(f"tool.{tool_name}") as span:
        span.set_attribute("tool.name", tool_name)
        span.set_attribute("tool.success", success)
        span.set_attribute("tool.duration_ms", duration_ms)
        span.set_attribute("tool.row_count", row_count)
        if not success:
            span.set_attribute("tool.error", True)
