# Upgrading from 0.4 to 0.5

Breaking changes:

- removed support for setting target api domain in script tag
    `<script type="text/javascript" src="sdk.js#domain=local.widgetic.com"></script>`
    use instead:
    ```
    <script type="text/javascript">
      window.widgeticOptions = {
        domain: 'local.widgetic.com'
      }
    </script>
    <script type="text/javascript" src="sdk.js"></script>
    ```