
import streamlit as st
import pandas as pd
import mysql.connector
import plotly.express as px

st.set_page_config(
    page_title="Global Seismic Trends",
    page_icon="🌍",
    layout="wide"
)

st.title("🌍 Global Seismic Trends")
st.subheader("Data-Driven Earthquake Insights")
st.caption("Explore five years of earthquake data from the USGS dataset.")

@st.cache_data(ttl=300)
def load_data():
    config = st.secrets["mysql"]

    connection = mysql.connector.connect(
        host=config["host"],
        user=config["user"],
        password=config["password"],
        database=config["database"]
    )

    try:
        query = """
            SELECT
                id, time, latitude, longitude, depth_km, mag,
                magType, place, status, tsunami, sig, net,
                nst, rms, gap, type, year, month, day_of_week,
                depth_category, strong_earthquake, major_earthquake
            FROM earthquakes
        """

        data = pd.read_sql(query, connection)
    finally:
        connection.close()

    data["time"] = pd.to_datetime(data["time"], errors="coerce")
    data["year"] = pd.to_numeric(data["year"], errors="coerce")
    data["mag"] = pd.to_numeric(data["mag"], errors="coerce")
    data["depth_km"] = pd.to_numeric(data["depth_km"], errors="coerce")

    return data


try:
    df = load_data()

    if df.empty:
        st.warning("No earthquake records were returned by MySQL.")
        st.stop()

    st.sidebar.header("Filter earthquakes")

    available_years = sorted(df["year"].dropna().astype(int).unique())

    selected_years = st.sidebar.multiselect(
        "Year",
        available_years,
        default=available_years
    )

    min_mag = float(df["mag"].min())
    max_mag = float(df["mag"].max())

    magnitude_range = st.sidebar.slider(
        "Magnitude range",
        min_value=min_mag,
        max_value=max_mag,
        value=(min_mag, max_mag)
    )

    depth_values = df["depth_km"].dropna()

    if not depth_values.empty:
        depth_range = st.sidebar.slider(
            "Depth range (km)",
            min_value=float(depth_values.min()),
            max_value=float(depth_values.max()),
            value=(float(depth_values.min()), float(depth_values.max()))
        )
    else:
        depth_range = (0.0, 0.0)

    filtered = df[
        df["year"].isin(selected_years)
        & df["mag"].between(*magnitude_range)
        & df["depth_km"].between(*depth_range)
    ].copy()

    st.markdown("### Overview")
    st.caption(f"Total records in database: {len(df):,}")

    c1, c2, c3, c4 = st.columns(4)

    c1.metric("Filtered earthquake records", f"{len(filtered):,}")

    if not filtered.empty:
        c2.metric("Strongest magnitude", f"{filtered['mag'].max():.2f}")
        c3.metric("Average magnitude", f"{filtered['mag'].mean():.2f}")
        c4.metric("Maximum depth", f"{filtered['depth_km'].max():.1f} km")
    else:
        c2.metric("Strongest magnitude", "—")
        c3.metric("Average magnitude", "—")
        c4.metric("Maximum depth", "—")
        st.info("No records match the selected filters.")

    if not filtered.empty:
        st.markdown("### Earthquake trends")

        yearly = (
            filtered.groupby("year")
            .size()
            .reset_index(name="earthquake_count")
        )

        fig_year = px.line(
            yearly,
            x="year",
            y="earthquake_count",
            markers=True,
            title="Earthquake records by year"
        )
        st.plotly_chart(fig_year, use_container_width=True)

        left, right = st.columns(2)

        with left:
            magnitude_data = filtered.dropna(subset=["mag"])
            fig_mag = px.histogram(
                magnitude_data,
                x="mag",
                nbins=40,
                title="Magnitude distribution"
            )
            st.plotly_chart(fig_mag, use_container_width=True)

        with right:
            depth_data = filtered.dropna(subset=["depth_km"])
            fig_depth = px.histogram(
                depth_data,
                x="depth_km",
                nbins=40,
                title="Earthquake depth distribution"
            )
            st.plotly_chart(fig_depth, use_container_width=True)

        st.markdown("### Reporting and event patterns")

        left, right = st.columns(2)

        with left:
            network_counts = (
                filtered["net"].dropna()
                .value_counts()
                .head(10)
                .rename_axis("network")
                .reset_index(name="record_count")
            )

            fig_network = px.bar(
                network_counts,
                x="record_count",
                y="network",
                orientation="h",
                title="Top reporting networks"
            )
            st.plotly_chart(fig_network, use_container_width=True)

        with right:
            type_counts = (
                filtered["type"].fillna("Unknown")
                .value_counts()
                .head(10)
                .rename_axis("event_type")
                .reset_index(name="record_count")
            )

            fig_type = px.bar(
                type_counts,
                x="record_count",
                y="event_type",
                orientation="h",
                title="Event types"
            )
            st.plotly_chart(fig_type, use_container_width=True)

        st.markdown("### Global earthquake distribution")

        st.caption(
            "Map shows up to 5,000 earthquake records "
            "from the current filters to keep the dashboard responsive."
        )

        map_data = filtered.dropna(
            subset=["latitude", "longitude", "mag"]
        )

        # Limit map points for better performance
        map_sample = map_data.sample(
            n=min(5000, len(map_data)),
            random_state=42
        )

        fig_map = px.scatter_geo(
            map_sample,
            lat="latitude",
            lon="longitude",
            color="mag",
            size="sig",
            size_max=12,
            hover_name="place",
            hover_data=["depth_km", "time"],
            projection="natural earth",
            title="Global earthquake locations"
        )

        fig_map.update_layout(
            height=550,
            margin=dict(l=0, r=0, t=50, b=0)
        )

        st.plotly_chart(fig_map, use_container_width=True)
        st.markdown("### Strongest earthquake records")

        strongest = (
            filtered.dropna(subset=["mag"])
            .nlargest(10, "mag")[
                ["time", "place", "mag", "depth_km", "tsunami", "status"]
            ]
        )

        st.dataframe(strongest, use_container_width=True)

        st.download_button(
            "Download filtered earthquake data (CSV)",
            data=filtered.to_csv(index=False).encode("utf-8"),
            file_name="filtered_earthquake_data.csv",
            mime="text/csv"
        )

    st.caption(
        "Source: USGS earthquake records stored in the "
        "global_seismic_trends MySQL database. "
        "Counts represent records returned by the selected filters."
    )

except Exception as error:
    st.error("The dashboard could not load the MySQL data.")
    st.info(
        "Check that MySQL is running, the connection settings are correct, "
        "and the earthquakes table contains the expected columns."
    )
    st.exception(error)
