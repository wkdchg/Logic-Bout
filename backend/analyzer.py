import json
import logging
import asyncio
from typing import Any

from prompts import ANALYSIS_SYSTEM

logger = logging.getLogger(__name__)

# Keep model string in one place to avoid drift between modules.
ANALYSIS_MODEL = "claude-sonnet-4-20250514"


def _ensure_list_of_strings(v: Any) -> list[str]:
    if not isinstance(v, list):
        raise ValueError("Expected an array of strings")
    return [str(x) for x in v]


async def analyze_debate_transcript(
    *,
    client: Any,
    transcript: str,
    max_tokens: int = 1000,
    model: str = ANALYSIS_MODEL,
) -> dict[str, Any]:
    """
    Calls Claude to analyze the debate transcript.

    Returns a dict matching ANALYSIS_SYSTEM JSON schema:
    {
      "strong_points": ["...","..."],
      "weak_points": ["...","..."],
      "persuasiveness_score": <int 1-10>,
      "verdict": "<one sentence>",
      "suggested_reading": "<one book or article title and author>"
    }
    """
    
    logger.info(f"Starting analysis with model: {model}, max_tokens: {max_tokens}")
    logger.debug(f"Transcript length: {len(transcript)} characters")

    try:
        logger.info("Sending request to Claude API...")
        response = await asyncio.wait_for(
            client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=ANALYSIS_SYSTEM,
                messages=[{"role": "user", "content": transcript}],
            ),
            timeout=60.0  # 60 second timeout
        )
        logger.info(f"API response received. Content type: {type(response.content)}, Length: {len(response.content)}")
        
    except asyncio.TimeoutError:
        logger.error("Claude API request timed out after 60 seconds")
        raise ValueError("Claude API request timed out. Please try again.")
    except Exception as e:
        logger.error(f"API request failed: {type(e).__name__}: {str(e)}", exc_info=True)
        raise ValueError(f"Failed to call Claude API: {type(e).__name__}: {str(e)}")

    try:
        if not response.content or len(response.content) == 0:
            raise ValueError("Empty response content from API")
            
        raw = response.content[0].text.strip()
        logger.info(f"Raw response text length: {len(raw)}")
        
        if not raw:
            logger.error(f"Empty response text. Full response object: {response}")
            raise ValueError(f"Empty response text from API")
        
        logger.debug(f"Raw response (first 200 chars): {raw[:200]}")
        
        # Remove markdown code block if present (```json ... ```)
        if raw.startswith("```"):
            logger.info("Detected markdown code block, extracting JSON")
            # Remove opening ```json or ```
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:].lstrip()
            # Remove closing ```
            raw = raw.rsplit("```", 1)[0].rstrip()
            logger.debug(f"Extracted JSON (first 200 chars): {raw[:200]}")
        
        analysis = json.loads(raw)
        logger.info("JSON parsing successful")
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {str(e)}. Raw text: {repr(raw[:500])}")
        raise ValueError(f"Invalid JSON from Claude: {str(e)}. Response: {repr(raw[:200])}")
    except Exception as e:
        logger.error(f"Error processing response: {type(e).__name__}: {str(e)}", exc_info=True)
        raise
    
    if not isinstance(analysis, dict):
        logger.error(f"Analysis is not dict, it's {type(analysis)}")
        raise ValueError("Claude returned non-object JSON")

    # Minimal validation to keep UI stable.
    try:
        strong_points = _ensure_list_of_strings(analysis["strong_points"])
        weak_points = _ensure_list_of_strings(analysis["weak_points"])
        persuasiveness_score = int(analysis["persuasiveness_score"])
        verdict = str(analysis["verdict"])
        suggested_reading = str(analysis["suggested_reading"])
        logger.info("All fields validated successfully")
    except KeyError as e:
        logger.error(f"Missing required field: {str(e)}. Analysis keys: {list(analysis.keys())}")
        raise ValueError(f"Missing required field in response: {str(e)}")
    except (ValueError, TypeError) as e:
        logger.error(f"Field validation failed: {type(e).__name__}: {str(e)}")
        raise

    return {
        "strong_points": strong_points,
        "weak_points": weak_points,
        "persuasiveness_score": persuasiveness_score,
        "verdict": verdict,
        "suggested_reading": suggested_reading,
    }

