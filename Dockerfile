FROM node:10-buster as builder

# plugins to install while building the container. By default no plugins are
# installed.
# If given a value, it has to be a space-separated, quoted list of plugin names.
#
# EXAMPLE:
#   ETHERPAD_PLUGINS="ep_codepad ep_author_neat"
ARG ETHERPAD_PLUGINS=

# By default, Etherpad container is built and run in "production" mode. This is
# leaner (development dependencies are not installed) and runs faster (among
# other things, assets are minified & compressed).
ENV NODE_ENV=production

WORKDIR /opt/etherpad-lite

COPY ./ ./

# Copy the configuration file.
COPY ./settings.json.docker /opt/etherpad-lite/settings.json

# install node dependencies for Etherpad
# Install the plugins, if ETHERPAD_PLUGINS is not empty.
#
# Bash trick: in the for loop ${ETHERPAD_PLUGINS} is NOT quoted, in order to be
# able to split at spaces.
# Fix permissions for root group
RUN apt-get update && \
    apt-get install -y --no-install-recommends python && \
    src/bin/installDeps.sh && \
    (cd src && npm install sqlite3) && \
    for PLUGIN_NAME in ${ETHERPAD_PLUGINS}; do npm install "${PLUGIN_NAME}" || exit 1; done && \
    chmod -R g=u .


FROM node:10-buster-slim

ENV NODE_ENV=production

# Follow the principle of least privilege: run as unprivileged user.
#
# Running as non-root enables running this image in platforms like OpenShift
# that do not allow images running as root.
RUN useradd --uid 5001 --create-home etherpad && \
    mkdir /opt/etherpad-lite && \
    chown etherpad:0 /opt/etherpad-lite

USER etherpad

WORKDIR /opt/etherpad-lite

COPY --from=builder --chown=etherpad:0 /opt/etherpad-lite .

# Fix permissions for root group
RUN chmod g=u .

EXPOSE 9001

CMD ["node", "--experimental-worker", "node_modules/ep_etherpad-lite/node/server.js"]
