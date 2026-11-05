"""Matplotlib helpers (static output works in HTML, PDF, DOCX and ePUB)."""

from __future__ import annotations

import matplotlib.pyplot as plt
import pandas as pd

_COLOR = "#3366CC"


def bar_counts(df: pd.DataFrame, label: str, value: str, title: str | None = None, horizontal: bool = True):
    """Bar chart of ``value`` per ``label``."""
    fig, ax = plt.subplots(figsize=(6.5, max(2.5, 0.3 * len(df)) if horizontal else 3.5))
    if horizontal:
        ax.barh(df[label], df[value], color=_COLOR)
        ax.invert_yaxis()
        ax.set_xlabel(value)
    else:
        ax.bar(df[label], df[value], color=_COLOR)
        ax.set_ylabel(value)
        plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
    if title:
        ax.set_title(title)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    plt.close(fig)
    return fig


def per_year(df: pd.DataFrame, year: str = "year", title: str | None = None, binwidth: int = 5):
    """Histogram of works per ``binwidth``-year period."""
    years = df[year].dropna().astype(int)
    fig, ax = plt.subplots(figsize=(6.5, 3.5))
    if len(years):
        bins = range(years.min() // binwidth * binwidth, years.max() + binwidth + 1, binwidth)
        ax.hist(years, bins=bins, color=_COLOR, edgecolor="white")
    ax.set_xlabel("Year")
    ax.set_ylabel("Number of works")
    if title:
        ax.set_title(title)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    plt.close(fig)
    return fig
