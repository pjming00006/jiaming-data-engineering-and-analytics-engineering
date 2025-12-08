brew install openjdk@17

echo 'export PATH="/usr/local/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
echo 'export JAVA_HOME="$(/usr/libexec/java_home -v17)"' >> ~/.zshrc
source ~/.zshrc

brew install sbt
# sbt sbtVersion

# To run
# sbt run