import { useCallback, useEffect, useRef, useState } from "react";

const STORAGE_KEY = "cx-dashboard-polling-interval";
const BACKOFF_INTERVAL = 30_000;
const MAX_CONSECUTIVE_FAILURES = 3;

function readStoredInterval(defaultInterval: number) {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored !== null) {
      const parsed = Number(stored);
      if ([0, 5000, 10000, 30000].includes(parsed)) return parsed;
    }
  } catch {
    // localStorage unavailable
  }
  return defaultInterval;
}

function writeStoredInterval(value: number) {
  try {
    localStorage.setItem(STORAGE_KEY, String(value));
  } catch {
    // localStorage unavailable
  }
}

type UsePollingOptions = {
  defaultInterval?: number;
};

type UsePollingReturn<T> = {
  data: T | null;
  error: string | null;
  isRefreshing: boolean;
  lastSyncedAt: number | null;
  interval: number;
  setInterval: (ms: number) => void;
};

export function usePolling<T>(
  fetchFn: (signal: AbortSignal) => Promise<T>,
  options: UsePollingOptions = {}
): UsePollingReturn<T> {
  const { defaultInterval = 10_000 } = options;
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<number | null>(null);
  const [interval, setIntervalState] = useState(() => readStoredInterval(defaultInterval));
  const consecutiveFailures = useRef(0);
  const userInterval = useRef(interval);

  const setInterval = useCallback((ms: number) => {
    setIntervalState(ms);
    userInterval.current = ms;
    writeStoredInterval(ms);
    consecutiveFailures.current = 0;
  }, []);

  useEffect(() => {
    let active = true;
    let timerId: ReturnType<typeof globalThis.setTimeout> | null = null;
    const controller = new AbortController();

    async function poll() {
      if (!active) return;
      setIsRefreshing(true);

      try {
        const result = await fetchFn(controller.signal);
        if (!active) return;
        setData(result);
        setError(null);
        setLastSyncedAt(Date.now());
        consecutiveFailures.current = 0;
        if (interval !== userInterval.current && userInterval.current !== 0) {
          setIntervalState(userInterval.current);
        }
      } catch (err) {
        if (!active || controller.signal.aborted) return;
        consecutiveFailures.current += 1;
        setError(err instanceof Error ? err.message : "未知错误");
        if (consecutiveFailures.current >= MAX_CONSECUTIVE_FAILURES && userInterval.current !== 0) {
          setIntervalState(BACKOFF_INTERVAL);
        }
      } finally {
        if (active) setIsRefreshing(false);
      }

      if (active && interval > 0) {
        timerId = globalThis.setTimeout(poll, interval);
      }
    }

    function handleVisibility() {
      if (document.hidden) {
        if (timerId) {
          clearTimeout(timerId);
          timerId = null;
        }
      } else {
        void poll();
      }
    }

    void poll();
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      active = false;
      controller.abort();
      if (timerId) clearTimeout(timerId);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [fetchFn, interval]);

  return { data, error, isRefreshing, lastSyncedAt, interval, setInterval };
}
