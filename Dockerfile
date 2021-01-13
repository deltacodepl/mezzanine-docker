FROM ubuntu:14.04
LABEL maintainer="hello@devopsengineer.me"

ARG GUNICORN_VERSION=">=17.0.0,<19.0.0"
ARG MEZZANINE_VERSION="==3.1.10"
ARG PYTHON_LDAP_VERSION=">=3.2.0,<3.3.0"
ARG DJANGO_AUTH_LDAP_VERSION=">=1.7.0,<1.8.0"
ARG PSYCOPG2_VERSION=">=2.8.0,<2.9.0"

# Set the Mezzanine project's name (mandatory).
# Configuring the project is done by modifying the local_settings.py file, as usual.
ENV MEZZANINE_PROJECT="khorlo"
ENV GUNICORN_WORKERS="2"
ENV GUNICORN_PORT="8000"

ENV MEZZANINE_UID="78950" MEZZANINE_GID="78950"

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc \
      libjpeg-dev \
      software-properties-common
RUN apt-add-repository ppa:fkrull/deadsnakes
RUN apt-get update && apt-get install -y --no-install-recommends \
      python2.7

RUN apt-get update && apt-get install -y --no-install-recommends \
      python-dev \
      python-pip \
      zlib1g \
      zlib1g-dev
RUN pip install -U pip==19.3.1 && \
    pip install setuptools==44 && \
    pip install Pillow==6.2.1 && \
    pip install mezzanine${MEZZANINE_VERSION} gunicorn${GUNICORN_VERSION}

RUN apt-get clean

# Use standard directories to better show the intention and keep things ordered.
RUN mkdir -p /srv/mezzanine /etc/nginx/conf.d && \
    touch /etc/nginx/conf.d/mezzanine.conf && \
    chown "${MEZZANINE_UID}:${MEZZANINE_GID}" /srv/mezzanine /etc/nginx/conf.d/mezzanine.conf

# Add simple configuration template for nginx. Configurations are generated to the usual nginx
# conf.d directory so it's simpler to use volumes for sharing the configuration with an
# nginx-container.
COPY nginx.conf.tpl /etc/nginx/mezzanine.conf.tpl

EXPOSE 8000
USER ${MEZZANINE_UID}:${MEZZANINE_GID}
COPY mezzanine/ /srv/mezzanine/

WORKDIR /srv/mezzanine
CMD set -eu; \
    [ -z "$MEZZANINE_PROJECT" ] && (echo "MEZZANINE_PROJECT has to be defined!" >&2; exit 1); \
    cd "$MEZZANINE_PROJECT" || (echo "Failed to descend into project directory. Does it exist?" >&2; exit 1); \
    # Generate nginx-configuration.
    # NOTE: since this container can modify that configuration file by default, it could provide
    # a way for this container to affect the container running nginx. For extra security, you can
    # change the file ownership to root, for example.
    sed -r "s/MEZZANINE_PROJECT/$MEZZANINE_PROJECT/g" /etc/nginx/mezzanine.conf.tpl > "/etc/nginx/conf.d/mezzanine.conf" || echo "Failed to generate Nginx configuration! Skipping." >&2; \
    exec gunicorn -b "0.0.0.0:${GUNICORN_PORT}" -w "$GUNICORN_WORKERS" "wsgi"
