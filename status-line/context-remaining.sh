#!/bin/bash
# Minimal statusline: context window remaining only

input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    echo "? remaining"
    exit 0
fi

# Get the last assistant message with usage info
last_usage=$(tac "$transcript_path" | grep -m1 '"cache_read_input_tokens"' | jq -r '.message.usage // empty' 2>/dev/null)

if [ -z "$last_usage" ]; then
    echo "? remaining"
    exit 0
fi

# Total context = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
input_tokens=$(echo "$last_usage" | jq -r '.input_tokens // 0')
cache_creation=$(echo "$last_usage" | jq -r '.cache_creation_input_tokens // 0')
cache_read=$(echo "$last_usage" | jq -r '.cache_read_input_tokens // 0')

total=$((input_tokens + cache_creation + cache_read))
remaining=$((200000 - total))

formatted=$(printf "%'d" $remaining 2>/dev/null || echo "$remaining")
echo "${formatted} left"
