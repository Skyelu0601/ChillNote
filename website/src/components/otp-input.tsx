"use client";

import { useRef, type ClipboardEvent, type KeyboardEvent } from "react";

type OtpInputProps = {
  value: string;
  onChange: (next: string) => void;
  length?: number;
  disabled?: boolean;
  autoFocus?: boolean;
  onComplete?: (code: string) => void;
};

/** Segmented one-time-code input: N single-digit boxes with auto-advance + paste. */
export function OtpInput({
  value,
  onChange,
  length = 6,
  disabled = false,
  autoFocus = false,
  onComplete,
}: OtpInputProps) {
  const inputs = useRef<Array<HTMLInputElement | null>>([]);
  const digits = Array.from({ length }, (_, i) => value[i] ?? "");

  function focusBox(index: number) {
    const el = inputs.current[Math.max(0, Math.min(index, length - 1))];
    el?.focus();
    el?.select();
  }

  function setDigit(index: number, digit: string) {
    const next = digits.slice();
    next[index] = digit;
    const joined = next.join("").slice(0, length);
    onChange(joined);
    return joined;
  }

  function handleChange(index: number, raw: string) {
    const cleaned = raw.replace(/\D/g, "");
    if (!cleaned) {
      setDigit(index, "");
      return;
    }
    // If the user typed/pasted multiple chars into one box, spread them.
    if (cleaned.length > 1) {
      const joined = (value.slice(0, index) + cleaned).replace(/\D/g, "").slice(0, length);
      onChange(joined);
      focusBox(joined.length);
      if (joined.length === length) onComplete?.(joined);
      return;
    }
    const joined = setDigit(index, cleaned);
    if (index < length - 1) focusBox(index + 1);
    if (joined.length === length) onComplete?.(joined);
  }

  function handleKeyDown(index: number, event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Backspace") {
      if (digits[index]) {
        setDigit(index, "");
      } else if (index > 0) {
        focusBox(index - 1);
        setDigit(index - 1, "");
      }
      event.preventDefault();
    } else if (event.key === "ArrowLeft" && index > 0) {
      focusBox(index - 1);
      event.preventDefault();
    } else if (event.key === "ArrowRight" && index < length - 1) {
      focusBox(index + 1);
      event.preventDefault();
    }
  }

  function handlePaste(event: ClipboardEvent<HTMLInputElement>) {
    const pasted = event.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
    if (!pasted) return;
    event.preventDefault();
    onChange(pasted);
    focusBox(pasted.length);
    if (pasted.length === length) onComplete?.(pasted);
  }

  return (
    <div className="lp-otp" role="group" aria-label="Verification code">
      {digits.map((digit, index) => (
        <input
          key={index}
          ref={(el) => {
            inputs.current[index] = el;
          }}
          className="lp-otp-box"
          value={digit}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          onPaste={handlePaste}
          onFocus={(e) => e.target.select()}
          inputMode="numeric"
          autoComplete={index === 0 ? "one-time-code" : "off"}
          maxLength={1}
          disabled={disabled}
          autoFocus={autoFocus && index === 0}
          aria-label={`Digit ${index + 1}`}
        />
      ))}
    </div>
  );
}
