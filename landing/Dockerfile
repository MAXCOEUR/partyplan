# syntax=docker/dockerfile:1

# Site vitrine statique. Aucune étape de compilation tant qu'aucun générateur
# (Astro, Eleventy) n'est introduit : le contenu de `public/` est servi tel quel.
FROM nginx:1.27-alpine AS runtime
COPY public/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
