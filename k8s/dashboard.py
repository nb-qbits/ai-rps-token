import streamlit as st
import subprocess
import pandas as pd
import matplotlib.pyplot as plt

st.set_page_config(page_title="AI GPU Dashboard", layout="wide")

st.title("🚀 AI Inference Performance Dashboard")

# -------------------------------
# Sidebar
# -------------------------------
st.sidebar.header("⚙️ Test Configuration")

concurrency = st.sidebar.slider("Concurrency", 1, 50, 10)
requests = st.sidebar.slider("Requests", 10, 200, 40)

run = st.sidebar.button("▶️ Run Test")
sweep = st.sidebar.button("📈 Run Concurrency Sweep")
refresh_gpu = st.sidebar.button("🔄 Refresh GPU Stats")
debug = st.sidebar.checkbox("🧪 Show Debug")

# -------------------------------
# GPU Stats
# -------------------------------
def get_gpu_stats():
    try:
        pod_cmd = "oc get pods -n vllm-lab --no-headers | grep vllm | awk '{print $1}'"
        pod = subprocess.run(pod_cmd, shell=True, capture_output=True, text=True).stdout.strip()

        if not pod:
            return None, None

        cmd = f"oc exec -n vllm-lab {pod} -- nvidia-smi dmon -s pucm -c 1"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        lines = result.stdout.splitlines()
        if len(lines) > 2:
            parts = lines[-1].split()

            sm = int(parts[4]) if parts[4].isdigit() else 0
            mem = int(parts[5]) if parts[5].isdigit() else 0

            return sm, mem
    except:
        pass

    return None, None


# -------------------------------
# Run Test
# -------------------------------
def run_test(concurrency, requests):
    cmd = f"CONCURRENCY={concurrency} REQUESTS={requests} ./test.sh"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if debug:
        st.subheader("🧪 Raw Output")
        st.text(cmd)
        st.text(result.stdout)
        st.text(result.stderr)

    data = []

    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            try:
                tokens = int(parts[0])
                tps = float(parts[1])
                rps = float(parts[2])
                if tokens in [50, 100]:
                    data.append((tokens, tps, rps))
            except:
                continue

    df = pd.DataFrame(data, columns=["Tokens", "Tokens/sec", "RPS"])

    return df.sort_values("Tokens")


# -------------------------------
# Concurrency Sweep
# -------------------------------
def run_sweep(requests):
    concurrency_levels = [2, 4, 8, 16, 24]
    results = []

    progress = st.progress(0)

    for i, c in enumerate(concurrency_levels):
        cmd = f"CONCURRENCY={c} REQUESTS={requests} ./test.sh"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 3:
                try:
                    tokens = int(parts[0])
                    tps = float(parts[1])
                    rps = float(parts[2])

                    if tokens == 100:
                        results.append((c, tps, rps))
                except:
                    continue

        progress.progress((i + 1) / len(concurrency_levels))

    df = pd.DataFrame(results, columns=["Concurrency", "Tokens/sec", "RPS"])
    return df


# -------------------------------
# GPU PANEL
# -------------------------------
st.subheader("🧠 GPU Live Utilization")

col1, col2, col3 = st.columns(3)

sm, mem = get_gpu_stats()

if sm is not None:
    col1.metric("SM Utilization", f"{sm}%")
    col2.metric("Memory Utilization", f"{mem}%")

    if sm > 90:
        col3.success("🔥 GPU Saturated")
    elif sm > 50:
        col3.warning("⚡ Moderate Utilization")
    else:
        col3.info("💤 Underutilized")
else:
    st.error("❌ Could not fetch GPU stats")

# -------------------------------
# RUN TEST
# -------------------------------
if run:
    st.info("Running test...")

    df = run_test(concurrency, requests)

    st.success("Test completed")

    if df.empty:
        st.warning("No data returned from test.sh")
    else:
        col1, col2 = st.columns(2)

        with col1:
            st.subheader("📊 Results Table")
            st.dataframe(df)

        with col2:
            st.subheader("📈 Tokens/sec vs Tokens")
            fig, ax = plt.subplots()
            ax.plot(df["Tokens"], df["Tokens/sec"], marker='o')
            ax.set_xlabel("Tokens")
            ax.set_ylabel("Tokens/sec")
            ax.grid()
            st.pyplot(fig)

        st.subheader("📈 RPS vs Tokens")
        fig2, ax2 = plt.subplots()
        ax2.plot(df["Tokens"], df["RPS"], marker='o')
        ax2.set_xlabel("Tokens")
        ax2.set_ylabel("RPS")
        ax2.grid()
        st.pyplot(fig2)

        st.subheader("🧠 Insight")
        st.markdown("""
- Tokens/sec stabilizes → GPU is saturated  
- RPS increases when tokens decrease  
- Work is redistributed, not increased  
        """)

# -------------------------------
# SWEEP SECTION
# -------------------------------
if sweep:
    st.info("Running concurrency sweep...")

    df_sweep = run_sweep(requests)

    st.success("Sweep completed")

    if df_sweep.empty:
        st.warning("No data from sweep")
    else:
        st.subheader("📈 Tokens/sec vs Concurrency")

        fig, ax = plt.subplots()
        ax.plot(df_sweep["Concurrency"], df_sweep["Tokens/sec"], marker='o')
        ax.set_xlabel("Concurrency")
        ax.set_ylabel("Tokens/sec")
        ax.set_title("GPU Throughput Scaling")
        ax.grid()
        st.pyplot(fig)

        st.subheader("📈 RPS vs Concurrency")

        fig2, ax2 = plt.subplots()
        ax2.plot(df_sweep["Concurrency"], df_sweep["RPS"], marker='o')
        ax2.set_xlabel("Concurrency")
        ax2.set_ylabel("RPS")
        ax2.grid()
        st.pyplot(fig2)

        st.subheader("📊 Sweep Data")
        st.dataframe(df_sweep)

        # Saturation detection
        max_tps = df_sweep["Tokens/sec"].max()
        last_tps = df_sweep["Tokens/sec"].iloc[-1]

        growth = df_sweep["Tokens/sec"].pct_change().iloc[-1]

        if growth < 0.05:
            st.success("🔥 GPU Saturation Reached")
        else:
            st.info("⚡ GPU still scaling — increase concurrency")

        st.subheader("🧠 Insight")
        st.markdown("""
- Tokens/sec increases with concurrency → batching improves  
- Plateau indicates GPU saturation  
- Beyond this point, only RPS improves  
        """)