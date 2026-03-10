"""No-op flow."""

from prefect import flow


@flow
def noop():
    """Do nothing. Used so the platform can install Prefect and run deploy --all without error."""
    pass
